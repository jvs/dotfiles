# Tmux Configuration

## Lanes

A session has five lanes: **H**, **J**, **K**, **L**, and **;** (semicolon).
Each lane has its own ring of windows. Typical usage:

| Lane | Key | Purpose |
|------|-----|---------|
| H | alt+h | Tests |
| J | alt+j | Editor |
| K | alt+k | Git |
| L | alt+l | Claude + zen |
| ; | alt+; | Popup terminals |

When you switch to a lane, you see the window that was last focused in that lane.

**Flashback**: pressing the key for the lane you're already in jumps back to your previous lane. For example, if you're in lane-K and you press alt+k, you return to whichever lane you came from.

**Lazy initialization**: lanes are created on first use. A new session starts in lane-J with all existing windows assigned to it. Other lanes get their first window when you switch to them.

**Legacy sessions**: switching to a session that hasn't been initialized yet automatically assigns all its windows to lane-J.

**Orphan protection**: windows created outside the lane system (e.g. via `prefix+c` or scripts) are automatically tagged with the current lane via a tmux hook. As a fallback, any untagged windows are adopted into lane-J when switching lanes or cycling windows.

## Windows

| Key | Action |
|-----|--------|
| alt+u | Next window in current lane |
| alt+i | Previous window in current lane |
| alt+shift+N | New window in current lane |
| alt+shift+Q | Kill current window (with confirmation) |

Windows cycle within the current lane only. Creating a new window tags it with the current lane.

## Popup Terminals

| Key | Action |
|-----|--------|
| ctrl+j | Toggle popup terminal J |
| ctrl+k | Toggle popup terminal K |

Popup terminals appear as floating overlays (80% width/height). They live in the current session as windows named `popup-j` and `popup-k`, assigned to lane-semicolon.

**Terminal J** is contextual: each time you open it, it cd's to the underlying window's working directory (if the shell is idle). **Terminal K** is persistent: it keeps its cwd across opens, useful for staying in a fixed location like a repo root or logs directory.

Because they're real windows in lane-;, you can switch to lane-semicolon (alt+;) to view them as normal full-size windows. This is useful when copy-selection is broken in popup mode.

## Zen Mode

| Key | Action |
|-----|--------|
| alt+z | Toggle zen mode |
| alt+shift+Z | Resize zen mode (width prompt) |

Zen mode centers the current pane at 120 columns by adding blank panes on each side. The side panes are styled to match the background, creating visual margins.

- Works per-pane, not per-window or per-lane.
- Persists if you switch away and come back.
- Toggle again to remove the side panes.
- Requires terminal width > 130 columns.
- alt+shift+Z shows a prompt with the current pane width and lets you type a new width (e.g. 80 for prose, 200 for wide logs). Also available in the command palette as "Resize Zen Mode".

**Zen cleanup**: when the main pane of a zen window exits (e.g. via `exit`), the window is automatically killed instead of leaving orphaned side panes. This uses a `pane-exited` hook that checks if all remaining panes are zen panes.

> **Known issue**: if you manually split a zen window and then exit the original pane, the cleanup will kill the entire window — including the manual split. Avoid manual splits inside zen windows.

## Moving Windows Between Lanes

Available from the command palette (alt+y) as "Move Window to Another Lane", or from the menu (alt+n). Shows a picker to choose the target lane.

## Command Palette

Open with **alt+y**. An fzf-powered list of all available commands:

**Sessions**: Open Supertree, Create New Session, Choose Session, Kill Other Session, Rename Session, Switch to Last Session.

**Windows / Lanes**: Choose Window, Create New Window in Lane, Kill Current Window, Maximize Window, Move Window to Another Lane, Rename Window.

**Panes**: Kill Current Pane, Move Pane to New Window, Split Pane Across Middle, Split Pane Down Middle, Toggle Zen Mode, Resize Zen Mode.

**Utilities**: Display Clock, Toggle Floating Terminal J/K, Show World Time.

**tmux**: Detach All Other Clients, Detach from tmux, Enter Copy Mode, Kill Server, Reload tmux Configuration, Show Command Prompt, Show Messages, Toggle Status Bar, Show Client Info.

## General Navigation

| Key | Action |
|-----|--------|
| alt+n | Menu |
| alt+y | Command palette |
| alt+shift+S | Create new session |
| alt+shift+P | Switch to last session |
| alt+t | Tree view (sessions and windows) |
| alt+p | Session chooser (fzf) |
| alt+o | Supertree |

## Other

| Key | Action |
|-----|--------|
| ctrl+a | Secondary prefix |
| v (copy mode) | Begin selection |
| y (copy mode) | Copy selection |
| esc / q (copy mode) | Exit copy mode |

## State Storage

Lane state is stored as tmux options:

- **Session options**: `@lane_initialized`, `@current_lane`, `@prev_lane`, `@lane_h_window`, `@lane_j_window`, etc.
- **Window options**: `@lane` (which lane a window belongs to: h, j, k, l, or semi)
- **Pane options**: `@zen_pane` (1 on zen mode side panes)

## Known Issues

- **Global command file**: the command palette and supertree use a single temp file (`/tmp/tmux_command_to_run`) to pass the selected command back to tmux. If two sessions trigger a palette command at the same time, one can clobber the other.

## Files

- `tmux.conf` — keybindings and tmux settings
- `bin/tmux-commands.zsh` — all lane, popup, zen, and UI logic
