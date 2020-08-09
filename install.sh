#!/usr/bin/env bash

# Exit immediately if any step fails.
set -e

if [[ `uname` == "Darwin" ]]; then
    ./macOS/apple.sh
    ./macOS/brew.sh
fi


THIS_DIR="$(cd $(dirname $0) &>/dev/null && pwd && cd - &>/dev/null)"

git pull origin master

PLUGINS_DIR="${THIS_DIR}/custom/plugins"
mkdir -p "${PLUGINS_DIR}"


# Install oh-my-zsh:
$ sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

ln -sf "${THIS_DIR}" ~/dotfiles
ln -sf "${THIS_DIR}/zsh/.zshrc" ~/.zshrc
ln -sf "${THIS_DIR}/zsh/.p10k.zsh" ~/.p10k.zsh


# Install powerlevel10k.
# See: https://github.com/romkatv/powerlevel10k#oh-my-zsh
if [ ! -d "${PLUGINS-DIR}/powerlevel10k" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        "${PLUGINS_DIR}/powerlevel10k"
fi


# Install zsh-histdb.
# See: https://github.com/larkery/zsh-histdb#installation
if [ ! -d "${PLUGINS_DIR}/zsh-histdb" ]; then
    git clone https://github.com/larkery/zsh-histdb \
        "${PLUGINS_DIR}/zsh-histdb"
fi


# Install zsh-autosuggestions.
# See: https://github.com/zsh-users/zsh-autosuggestions/blob/master/INSTALL.md#oh-my-zsh
if [ ! -d "${PLUGINS_DIR}/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions \
        "${PLUGINS_DIR}/zsh-autosuggestions"
fi


# Install zsh-syntax-highlighting
# See: https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md#oh-my-zsh
if [ ! -d "${PLUGINS_DIR}/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
        "${PLUGINS_DIR}/zsh-syntax-highlighting"
fi
