#!/usr/bin/env bash

# Exit immediately if any step fails.
set -e

# Echo each command.
set -v

THIS_DIR="$(cd $(dirname $0) &>/dev/null && pwd && cd - &>/dev/null)"

# Yes, some people like stow. Some people like the --work-tree trick.
# I just want to use links and create them myself.

mkdir -p ~/.config/lf/
ln -sf "${THIS_DIR}/lfrc" ~/.config/lf/lfrc
ln -sf "${THIS_DIR}/tmux.conf" ~/.tmux.conf

# Install oh-my-zsh.
./zsh/setup.sh

CUSTOM_DIR="${HOME}/.oh-my-zsh/custom"
ln -sf "${THIS_DIR}/zsh/custom/exports.zsh" "${CUSTOM_DIR}/exports.zsh"
ln -sf "${THIS_DIR}/zsh/custom/history.zsh" "${CUSTOM_DIR}/history.zsh"

# Create these links after installing omz.
ln -sf "${THIS_DIR}/zsh/zshrc" "${HOME}/.zshrc"
ln -sf "${THIS_DIR}/zsh/p10k.zsh" "${HOME}/.p10k.zsh"

# Look for a bin folder.
if [[ -d ~/bin ]]; then
    BIN="~/bin"
elif [[ -d ~/.local/bin ]]; then
    BIN="~/.local/bin"
else
    # Create a bin folder and link to the ta script.
    BIN="~/.local/bin"
    mkdir -p "${BIN}"
fi

# Link to the "ta" script.
ln -sf "${THIS_DIR}/bin/ta" "${BIN}/ta"
