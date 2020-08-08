#!/usr/bin/env bash

set -e

# Make sure we’re using the latest Homebrew.
brew update

# Upgrade any already-installed formulae.
brew upgrade

function install_formula {
    brew list $1 || brew install $1
}

install_formula ack
install_formula icdiff
install_formula sqlite3
install_formula vim
install_formula wget
install_formula zsh

# brew cask install java
# brew install scala
# brew install sbt

# chsh -s $(which zsh)
# brew cask list iterm2 || brew cask install iterm2
# brew cask install visual-studio-code

brew cleanup
unset install_formula
