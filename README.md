# Setup My Environment

This repository contains scripts to setup my daily driver machine for software development. Feel free to check the source code to understand what is this script is currently doing. In a nut shell:

1. (Optional) install zsh
2. Installing OS basic tools for development
3. Install Homebrew
4. Install asdf
5. Install nodejs, python, golang, java and flutter with asdf
6. Install Android SDK Command Line

## Bash

Run this command on `bash` session:

```bash
ENV=bash /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/garasingulik/setupmyenv/main/setup-ubuntu.sh)"
```

## ZSH

Install `zsh` with `sudo apt install -y zsh` and then install [Oh My Zsh](https://ohmyz.sh/):

```
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

Run this command on `zsh` session:

```zsh
ENV=zsh /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/garasingulik/setupmyenv/main/setup-ubuntu.sh)"
```
