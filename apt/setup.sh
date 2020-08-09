#!/usr/bin/env bash

set -e
set -v

apt-get update

apt-get install -y \
    ack \
    curl \
    git \
    sqlite3 \
    vim \
    wget \
    zsh

# Install Visual Studio Code.
if command -v snap &> /dev/null ; then
    if ! command -v code &> /dev/null ; then
        sudo snap install --classic code
    fi
fi

# Copy Visual Studio Code settings.
if command -v code &> /dev/null ; then
    cp -r vscode/settings.json \
        "${HOME}/.config/Code/User/settings.json"
fi
