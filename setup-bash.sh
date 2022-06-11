#!/bin/sh
export PROFILE_CONFIG=~/.profile

# setup environment
sh -c "$(curl -fsSL https://raw.githubusercontent.com/garasingulik/setupmyenv/main/build-ubuntu.sh)"
