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


# Install supertree.
if [ ! -d "${HOME}/github/jvs/tmux-supertree" ]; then
    mkdir -p "${THIS_DIR}/runtime/"

    if [ ! -d "${THIS_DIR}/runtime/tmux-supertree" ]; then
        git clone https://github.com/jvs/tmux-supertree.git \
            "${THIS_DIR}/runtime/tmux-supertree"
    fi

    if ensure_go_installed; then
        make -C "${THIS_DIR}/runtime/tmux-supertree"
    else
        # TODO: download pre-built binary from GitHub when Go is not available.
        echo "Skipping tmux-supertree build (Go not available)."
    fi
fi


# Install tmux-hometown.
if ! command -v tmux-hometown &>/dev/null; then
    if ensure_go_installed; then
        go install github.com/jvs/tmux-hometown@latest
    else
        # Go is not available - try to download a pre-built binary from GitHub.
        os="$(uname -s)"
        arch="$(uname -m)"

        case "${os}-${arch}" in
            Darwin-arm64)   binary="tmux-hometown-darwin-arm64" ;;
            Darwin-x86_64)  binary="tmux-hometown-darwin-amd64" ;;
            Linux-aarch64)  binary="tmux-hometown-linux-arm64" ;;
            Linux-x86_64)   binary="tmux-hometown-linux-amd64" ;;
            *)
                echo "No pre-built tmux-hometown binary available for ${os}/${arch}."
                echo "Install Go and run: go install github.com/jvs/tmux-hometown@latest"
                binary=""
                ;;
        esac

        if [[ -n "$binary" ]]; then
            mkdir -p "${HOME}/.local/bin"
            curl -fsSL "https://github.com/jvs/tmux-hometown/releases/latest/download/${binary}" \
                -o "${HOME}/.local/bin/tmux-hometown"
            chmod +x "${HOME}/.local/bin/tmux-hometown"
            echo "tmux-hometown installed to ~/.local/bin/tmux-hometown."
            echo "Make sure ~/.local/bin is on your PATH."
        fi
    fi
fi
