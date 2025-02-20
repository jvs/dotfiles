# dotfiles

My dotfiles repo.


## Requirements

* git
* zsh
* chezmoi


### Install chezmoi

#### Using `brew`:

```bash
brew install chezmoi
```

#### Using `curl`:

```bash
sh -c "$(curl -fsLS get.chezmoi.io)"
```

#### Using `wget`:

sh -c "$(wget -qO- get.chezmoi.io)"

#### Other options:

See https://www.chezmoi.io/install/ for other ways to install `chezmoi`.


## Installation

```bash
chezmoi init https://github.com/jvs/dotfiles.git
```
