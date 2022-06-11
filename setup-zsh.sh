#!/bin/sh
export PROFILE_CONFIG=~/.zprofile

# install zsh package
sudo apt update && sudo apt install -y zsh

# set shell
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# setup environment
sh -c "$(curl -fsSL https://raw.githubusercontent.com/garasingulik/setupmyenv/main/build-ubuntu.sh)"
