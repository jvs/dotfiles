#!/usr/bin/env bash

# Exit immediately if any step fails.
set -e

# Echo each command.
set -v

THIS_DIR="$(cd $(dirname $0) &>/dev/null && pwd && cd - &>/dev/null)"

# Install oh-my-zsh.
if [ ! -d "${HOME}/.oh-my-zsh" ]; then
    echo "Installing oh-my-zsh"
    # See: https://github.com/ohmyzsh/ohmyzsh#unattended-install
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

CUSTOM_DIR="${HOME}/.oh-my-zsh/custom"
PLUGINS_DIR="${CUSTOM_DIR}/plugins"
THEMES_DIR="${CUSTOM_DIR}/themes"

mkdir -p "${PLUGINS_DIR}"
mkdir -p "${THEMES_DIR}"

# Install powerlevel10k.
# See: https://github.com/romkatv/powerlevel10k#oh-my-zsh
if [ ! -d "${THEMES_DIR}/powerlevel10k" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        "${THEMES_DIR}/powerlevel10k"
fi

# Install fzf-tab.
# See: https://github.com/Aloxaf/fzf-tab#oh-my-zsh
if [ ! -d "${PLUGINS_DIR}/fzf-tab" ]; then
    git clone https://github.com/Aloxaf/fzf-tab \
        "${PLUGINS_DIR}/fzf-tab"
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

# Install zsh-syntax-highlighting.
# See: https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md#oh-my-zsh
if [ ! -d "${PLUGINS_DIR}/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
        "${PLUGINS_DIR}/zsh-syntax-highlighting"
fi
