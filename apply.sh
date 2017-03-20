#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE}")"
git pull origin master


function df_apply_dotfiles() {
    rsync \
        --exclude ".git/" \
        --exclude ".DS_Store" \
        --exclude "LICENSE" \
        --exclude "Preferences.sublime-settings" \
        --exclude "README.md" \
        --exclude "apply.sh" \
        --exclude "brew.sh" \
        -avh --no-perms . ~;

    source ~/.bash_profile;

    # Copy sublime settings.
    cp -r Preferences.sublime-settings \
        ~/Library/Application\ Support/Sublime\ Text*/Packages/User
}

if [ "$1" == "--force" -o "$1" == "-f" ]; then
    df_apply_dotfiles
else
    read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        df_apply_dotfiles
    fi
fi

unset df_apply_dotfiles
