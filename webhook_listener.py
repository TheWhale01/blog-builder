import os
import git
import shutil
import uvicorn
import subprocess
from pathlib import Path
from fastapi import FastAPI

app = FastAPI()
working_dir = os.environ.get("WORKING_DIR", "/var/lib/blog-builder")

def git_clone():
    repo_url = "https://github.com/TheWhale01/blog-ideas"
    repo = git.Repo.clone_from(repo_url, os.path.join(working_dir, "blog-ideas"))

def git_pull():
    repo = git.Repo(os.path.join(working_dir, "blog-ideas"))
    origin = repo.remote(name="origin")
    origin.pull()

def compile_site():
    subprocess.run(["hugo"], cwd=os.path.join(working_dir, "site"), shell=True, check=True)

def create_site():
    repo_dir = os.path.join(working_dir, "site")
    hugo_conf = '''baseURL = 'https://blog.thewhale.fr'
languageCode = 'fr-fr'
title = "Whale's Blog"
theme = "PaperMod"
'''
    print("Creating site...")
    subprocess.run(["hugo", "new", "site", repo_dir], cwd=working_dir, check=True)
    subprocess.run(["git", "submodule", "add", "--depth=1", "-f", "https://github.com/adityatelange/hugo-PaperMod.git", "themes/PaperMod"], cwd=repo_dir, check=True)
    subprocess.run(["git", "submodule", "update", "--init", "--recursive"], cwd=repo_dir, check=True)
    with open(os.path.join(working_dir, 'site/hugo.toml'), 'w') as file:
        file.write(hugo_conf)
    shutil.rmtree(os.path.join(working_dir, "site/content"))
    shutil.rmtree(os.path.join(working_dir, "site/static"))
    os.symlink(os.path.join(working_dir, "blog-ideas/content"), os.path.join(working_dir, "site/content"))
    os.symlink(os.path.join(working_dir, "blog-ideas/static"), os.path.join(working_dir, "site/static"))
    compile_site()

@app.post("/webhook")
def webhook():
    git_pull()
    compile_site()

if __name__ == '__main__':
    if not os.path.exists(os.path.join(working_dir, "blog-ideas")):
        git_clone()
    else:
        git_pull()
    if not os.path.exists(os.path.join(working_dir, "site")):
        create_site()
    uvicorn.run("webhook_listener:app", host="127.0.0.1", port=8882, reload=True)
