import os
import git
import shutil
import uvicorn
import subprocess
from pathlib import Path
from fastapi import FastAPI

app = FastAPI()

def git_clone():
    repo_url = "https://github.com/TheWhale01/blog-ideas"
    local_path = "./blog-ideas"
    repo = git.Repo.clone_from(repo_url, os.path.abspath("./blog-ideas"))

def git_pull():
    repo = git.Repo(os.path.abspath('./blog-ideas'))
    origin = repo.remote(name="origin")
    origin.pull()

def create_site():
    repo_dir = "site"
    hugo_conf = '''baseURL = 'https://blog.thewhale.fr'
languageCode = 'fr-fr'
title = "Whale's Blog"
'''
    print("Creating site...")
    os.system(f"hugo new site {repo_dir}")
    subprocess.run(["git", "submodule", "add", "--depth=1", "-f", "https://github.com/adityatelange/hugo-PaperMod.git", "themes/PaperMod"], cwd=repo_dir, check=True)
    subprocess.run(["git", "submodule", "update", "--init", "--recursive"], cwd=repo_dir, check=True)
    with open('site/hugo.toml', 'w') as file:
        file.write(hugo_conf)
    shutil.rmtree("site/content")
    shutil.rmtree("site/static")
    os.symlink(os.path.abspath("./blog-ideas/content"), "./site/content")
    os.symlink(os.path.abspath("./blog-ideas/static"), "./site/static")

@app.post("/webhook")
def webhook():
    git_pull()

if __name__ == '__main__':
    if not os.path.exists("./blog-ideas"):
        git_clone()
    else:
        git_pull()
    if not os.path.exists("./site"):
        create_site()
    uvicorn.run("webhook_listener:app", host="127.0.0.1", port=8882, reload=True)
