#!/usr/bin/env bash

# Exit immediately if any step fails.
set -e

# Echo each command.
set -v

THIS_DIR="$(cd "$(dirname "$0")" &>/dev/null && pwd && cd - &>/dev/null)"

# Load utility functions.
source "${THIS_DIR}/utils/install_go.sh"


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


# Create these links after installing omz.
ln -sf "${THIS_DIR}/zsh/custom/exports.zsh" "${CUSTOM_DIR}/exports.zsh"
ln -sf "${THIS_DIR}/zsh/custom/history.zsh" "${CUSTOM_DIR}/history.zsh"
ln -sf "${THIS_DIR}/zsh/zshenv" "${HOME}/.zshenv"
ln -sf "${THIS_DIR}/zsh/zshrc" "${HOME}/.zshrc"
ln -sf "${THIS_DIR}/zsh/p10k.zsh" "${HOME}/.p10k.zsh"


# Create a bin directory if it doesn't exist.
mkdir -p "${HOME}/bin/"

# Install git-addp.
ln -sf "${THIS_DIR}/bin/git-addp.zsh" "${HOME}/bin/git-addp.zsh"

# Install pi-utils.
ln -sf "${THIS_DIR}/bin/pi-utils.sh" "${HOME}/bin/pi-utils.sh"


# Create links for the tmux files.
ln -sf "${THIS_DIR}/tmux.conf" "${HOME}/.tmux.conf"
ln -sf "${THIS_DIR}/bin/tmux-commands.zsh" "${HOME}/bin/tmux-commands.zsh"


install_go_tool() {
    local name="$1"
    local repo="${2:-$name}"
    local install_path="${3:-github.com/jvs/${repo}@latest}"

    if command -v "$name" &>/dev/null; then
        return
    fi

    if ensure_go_installed; then
        go install "${install_path}"
        return
    fi

    # Go is not available - try to download a pre-built binary from GitHub.
    local os arch binary
    os="$(uname -s)"
    arch="$(uname -m)"

    case "${os}-${arch}" in
        Darwin-arm64)   binary="${name}-darwin-arm64" ;;
        Darwin-x86_64)  binary="${name}-darwin-amd64" ;;
        Linux-aarch64)  binary="${name}-linux-arm64" ;;
        Linux-x86_64)   binary="${name}-linux-amd64" ;;
        *)
            echo "No pre-built ${name} binary available for ${os}/${arch}."
            echo "Install Go and run: go install ${install_path}"
            return
            ;;
    esac

    mkdir -p "${HOME}/.local/bin"
    curl -fsSL "https://github.com/jvs/${repo}/releases/latest/download/${binary}" \
        -o "${HOME}/.local/bin/${name}"
    chmod +x "${HOME}/.local/bin/${name}"
    echo "${name} installed to ~/.local/bin/${name}."
    echo "Make sure ~/.local/bin is on your PATH."
}

install_go_tool tmux-hometown
install_go_tool tmux-treefort
install_go_tool kit tmux-fieldkit github.com/jvs/tmux-fieldkit/cmd/kit@latest
