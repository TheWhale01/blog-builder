import os
import re
import git
import shutil
import uvicorn
import subprocess
from pathlib import Path
from fastapi import FastAPI

app = FastAPI()
working_dir = os.environ.get("WORKING_DIR", "./")

def modify_md_files():
    md_files: list[str] = list(Path(os.path.join(working_dir, "site/content/posts")).rglob("*.md"))
    for file in md_files:
        modify_img_links(file)

def modify_img_links(filename: str):
    pattern = re.compile(r'\[([^\]]+)\]\(([^)]+)\)')
    with open(filename, 'r') as read_md:
        with open(f"{filename}_wr.md", 'w') as write_md:
            while line := read_md.readline():
                match = pattern.search(line)
                if match:
                    href = match.group(2) \
                        .replace('/static', '') \
                        .replace('/content', '') \
                        .replace('.md', '')
                    href = href.lower() + '/'
                    link = f"[{match.group(1)}]({href})"
                    line = line.replace(match.group(0), link)
                    write_md.write(line)
                else:
                    write_md.write(line)
    shutil.os.remove(filename)
    os.rename(f"{filename}_wr.md", filename)

def git_clone():
    repo_url = "https://github.com/TheWhale01/blog-ideas"
    repo = git.Repo.clone_from(repo_url, os.path.join(working_dir, "blog-ideas"))

def git_pull():
    repo = git.Repo(os.path.join(working_dir, "blog-ideas"))
    origin = repo.remote(name="origin")
    origin.pull()

def compile_site():
    subprocess.run(["hugo"], cwd=os.path.join(working_dir, "site"), shell=True, check=True)

def configure_hugo():
    shutil.os.remove(os.path.join(working_dir, "site/hugo.yaml"))
    shutil.rmtree(os.path.join(working_dir, "site/content"))
    shutil.rmtree(os.path.join(working_dir, "site/static"))
    os.symlink(os.path.join(working_dir, "blog-ideas/content"), os.path.join(working_dir, "site/content"))
    os.symlink(os.path.join(working_dir, "blog-ideas/static"), os.path.join(working_dir, "site/static"))
    os.symlink(os.path.join(working_dir, "conf/hugo.yaml"), os.path.join(working_dir, "site/hugo.yaml"))

def create_site():
    repo_dir = os.path.join(working_dir, "site")
    print("Creating site...")
    subprocess.run("git init", cwd=working_dir, check=True, shell=True)
    subprocess.run(f"hugo new site {repo_dir} --format yaml", cwd=working_dir, check=True, shell=True)
    subprocess.run("git submodule add --depth=1 -f https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod", cwd=repo_dir, check=True, shell=True)
    subprocess.run("git submodule update --init --recursive", cwd=repo_dir, check=True, shell=True)
    configure_hugo()
    compile_site()

@app.post("/webhook")
def webhook():
    git_pull()
    modify_md_files()
    compile_site()

if __name__ == '__main__':
    if not os.path.exists(os.path.join(working_dir, "blog-ideas")):
        git_clone()
    else:
        git_pull()
    if not os.path.exists(os.path.join(working_dir, "site")):
        create_site()
    if not os.path.exists(os.path.join(working_dir, "site/public")):
        compile_site()
    webhook()
    uvicorn.run("main:app", host="0.0.0.0", port=8882, reload=False)
