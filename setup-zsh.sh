#!/bin/sh

# install zsh package
sudo apt update && sudo apt install -y zsh

# set shell
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
