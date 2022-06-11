# Setup My Environment
Script to Setup Development Environment

## Bash

Run this command on `bash` session:

```bash
PROFILE_CONFIG=~/.profile /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/garasingulik/setupmyenv/main/setup-ubuntu.sh)"
```

## ZSH

Install `zsh` with `sudo apt install -y zsh` and then install [Oh My Zsh](https://ohmyz.sh/):

```
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

Run this command on `zsh` session:

```zsh
PROFILE_CONFIG=~/.zprofile /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/garasingulik/setupmyenv/main/setup-ubuntu.sh)"
```
