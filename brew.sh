#!/usr/bin/env bash

# Make sure we’re using the latest Homebrew.
brew update

# Upgrade any already-installed formulae.
brew upgrade

# Install various tools.
brew install git
brew install bash-completion
brew cask install java
brew install scala
brew install sbt
brew install wget
brew install ack

# Remove outdated versions from the cellar.
brew cleanup
