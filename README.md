# dotfiles

My dotfiles repo.


## Requirements

* git
* zsh
* chezmoi
* fzf


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
chezmoi init jvs
chezmoi diff
chezmoi apply -v
```


## Usage

Pull latest changes: `chezmoi update`
Apply latest changes: `chezmoi apply -v`


## tmux key bindings

| Key Binding | Description |
|-------------|-------------|
| `ctrl+a` | Prefix |
| `ctrl+a` `?` | List all key bindings |
| `alt+m` | Open the main menu |
| `alt+m, s` | Create a new session |
| `alt+p` | Open session chooser to swtich sessions |
| `alt+t` | Open a tree view to select a session and window |
| `alt+h` | Switch to previous session |
| `alt+g` | Open a terminal in a popup window |
| `alt+j` | Switch to next window |
| `alt+k` | Switch to previous window |
| `alt+m, q` | Open chooser to kill a session |
| `shift+alt+{HJKL}` | Navigate panes |

More options are available in the menu, accessible with `alt+m`.


## TODO

### Messed up key bindings:

- switch to previous session


### Missing key bindings:

- switch to previous window
- popup window chooser, or alt+t but just for current session
- close current window
- chooser to kill a window


### Other things:

- In the `ta` script, don't always create that session when reconnecting.
