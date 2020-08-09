#!/usr/bin/env bash

# Disable press-and-hold for keys in favor of key repeat.
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# See: https://medium.com/vunamhung/set-a-blazingly-fast-keyboard-repeat-rate-3d122ddac536
defaults write NSGlobalDomain KeyRepeat -int 0
defaults write NSGlobalDomain InitialKeyRepeat -int 10

# Copy vscode settings.
cp -r vscode/settings.json \
    ~/Library/Application\ Support/Code/User

# Copy sublime settings.
cp -r sublime/Preferences.sublime-settings \
    ~/Library/Application\ Support/Sublime\ Text*/Packages/User
