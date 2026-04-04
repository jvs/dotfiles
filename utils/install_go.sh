#!/usr/bin/env bash

# Ensures Go is installed, offering to install it if not.
# Intended to be sourced by install.sh, not executed directly.
#
# Usage:
#   source "${THIS_DIR}/utils/install_go.sh"
#   ensure_go_installed   # call before any block that needs `go`

_install_go_linux() {
    local arch
    case "$(uname -m)" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
        *)
            echo "Unsupported architecture: $(uname -m). Install Go manually: https://go.dev/dl/"
            return 1
            ;;
    esac

    local version
    version=$(curl -fsSL "https://go.dev/dl/?mode=json" \
        | grep -o '"version":"go[^"]*"' \
        | head -1 \
        | cut -d'"' -f4)

    if [[ -z "$version" ]]; then
        echo "Could not determine latest Go version. Install manually: https://go.dev/dl/"
        return 1
    fi

    local tarball="${version}.linux-${arch}.tar.gz"
    echo "Installing ${version} to /usr/local/go ..."
    curl -fsSL "https://go.dev/dl/${tarball}" -o "/tmp/${tarball}"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "/tmp/${tarball}"
    rm "/tmp/${tarball}"

    # Make go available for the remainder of this script invocation.
    export PATH="$PATH:/usr/local/go/bin"
    echo "Go installed. You may need to add /usr/local/go/bin to your PATH."
}

ensure_go_installed() {
    # Nothing to do if go is already on the PATH.
    if command -v go &>/dev/null; then
        return 0
    fi

    echo "Go is not installed."

    if [[ "$(uname)" == "Darwin" ]] && command -v brew &>/dev/null; then
        read -p "Install Go via Homebrew? [y/N] " reply
        if [[ "$reply" =~ ^[Yy]$ ]]; then
            brew install go
        else
            echo "Please install Go from https://go.dev/dl/ then re-run this script."
            return 1
        fi
    elif [[ "$(uname)" == "Linux" ]]; then
        read -p "Install Go from go.dev (to /usr/local/go)? [y/N] " reply
        if [[ "$reply" =~ ^[Yy]$ ]]; then
            _install_go_linux
        else
            echo "Please install Go from https://go.dev/dl/ then re-run this script."
            return 1
        fi
    else
        echo "Please install Go from https://go.dev/dl/ then re-run this script."
        return 1
    fi
}
