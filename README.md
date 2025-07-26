# dotfiles

My dotfiles repo.


## Requirements

* git
* zsh
* fzf


### Notes

After installing `fzf` with homebrew, to set up shell integration, see:
  https://github.com/junegunn/fzf#setting-up-shell-integration


## Installation

```bash
./install.sh
```


## tmux key bindings

| Key Binding | Description |
|-------------|-------------|
| `ctrl+a` | Prefix |
| `ctrl+a` `?` | List all key bindings |
| `alt+h` | Switch to previous window |
| `alt+j` | Switch to next window |
| `alt+k` | Switch to previous window |
| `alt+l` | Switch to last session |
| `alt+n` | Open the main menu |
| `alt+o` | Open the window switcher menu |
| `alt+p` | Open session chooser to swtich sessions |
| `alt+t` | Open a tree view to select a session and window |
| `alt+y` | Open a command palette |
| `ctrl+j` | Open a terminal in a popup window |
| `ctrl+k` | Open a terminal in a popup window |
| `alt+n, q` | Open chooser to kill a session |
| `alt+n, s` | Create a new session |
| `shift+alt+{HJKL}` | Navigate panes |

More options are available in command palette, accessible with `alt+y`, or the
menu, accessible with `alt+n`.


## TODO


### Missing key bindings:

- popup window chooser, or alt+t but just for current session
- chooser to kill a window
