#!/usr/bin/env zsh

if [[ "$1" == "always-attach" ]]; then
  if [[ -z "$TMUX" ]]; then
    tmux attach || tmux new-session -A -s main
  fi

  exit 0
fi

if [[ -z "$TMUX" ]]; then
  echo "This script must be run from within tmux" >&2
  exit 1
fi


if [[ "$1" == "show-menu" ]]; then
  tmux display-menu -T "#[align=centre fg=green] tmux " -x C -y C \
    "Create New Session"          s "command-prompt -p \"New Session:\" \"new-session -A -s '%%'\"" \
    "Choose Session"              p "run-shell '~/bin/tmux-commands.sh choose-session'" \
    "Choose Window"               t "choose-tree -wZ" \
    "Switch to Last Session"      h "switch-client -l" \
    "Rename Session"              n "command-prompt -p \"Rename session:\" \"rename-session '%%'\"" \
    "Kill Session"                q "run-shell '~/bin/tmux-commands.sh kill-session'" \
    "" \
    "Create New Window"           w "new-window -c \"#{pane_current_path}\"" \
    "Choose Window in Session"    c "choose-tree -wf\"##{==:##{session_name},#{session_name}}\"" \
    "Switch to Last Window"       l "last-window" \
    "Open Terminal Popup"         m "run-shell '~/bin/tmux-commands.sh popup-terminal'" \
    "Rename Window"               r "command-prompt -p \"Rename window:\" \"rename-window '%%'\"" \
    "Kill Current Window"         e "confirm-before -p \"Kill window?\" kill-window" \
    "" \
    "Split Pane Down Middle"      \\ "split-window -h -c \"#{pane_current_path}\"" \
    "Split Pane Across Middle"    -  "split-window -v -c \"#{pane_current_path}\"" \
    "Move Pane to New Window"     o "break-pane -d" \
    "Kill Current Pane"           x "confirm-before -p \"Kill pane?\" kill-pane" \
    "" \
    "Enter Copy Mode"             v "copy-mode" \
    "Detach from tmux"            d "detach" \
    "Close menu"       "" ""

  exit 0
fi


if [[ $1 == "choose-session" ]]; then
  tmux display-popup -h 60% -w 60% -E "\
    tmux list-sessions -F '#{session_name}' \
    | sed '/^$/d' \
    | fzf \
      --reverse \
      --header jump-to-session \
      --preview 'tmux capture-pane -pt {}' \
      --bind 'enter:execute(tmux switch-client -t {})+accept'"

  exit 0
fi


if [[ $1 == "kill-session" ]]; then
  tmux display-popup -h 60% -w 60% -E "\
    tmux list-sessions -F '#{?session_attached,,#{session_name}}' \
    | sed '/^$/d' \
    | fzf \
      --reverse -m \
      --header=kill-session \
      --preview 'tmux capture-pane -pt {}' \
    | xargs -I {} tmux kill-session -t {}"

  exit 0
fi


if [[ $1 == "popup-terminal" ]]; then
  current_session=$(tmux display-message -p '#S')
  current_window=$(tmux display-message -p '#W')

  if [ "$current_session" = "popup-terminals" ]; then
    tmux detach-client
    exit 0
  fi

  if [ -z "$(tmux list-sessions -F '#{session_name}' | grep "^popup-terminals$")" ]; then
    tmux new-session -d -s "popup-terminals"
  fi

  popup_session="popup-terminals"
  popup_window="$current_session--$current_window"
  window_exists=$(tmux list-windows -t "$popup_session" -F '#{window_name}' | grep -c "^$popup_window$")

  if [ "$window_exists" -eq 0 ]; then
    tmux new-window -kd -n "$popup_window" -t "$popup_session" -c "#{pane_current_path}"
  fi

  tmux display-popup -h 80% -w 80% -E "tmux attach-session -t $popup_session:$popup_window"
  exit 0
fi


if [[ "$1" == "show-window-menu" ]]; then
  tmux list-windows -F '#I #W' \
    | awk 'BEGIN {ORS=" "} {print $2, NR, "\"select-window -t", $1 "\""}' \
    | xargs tmux display-menu -T "#[align=centre fg=green] tmux " -x C -y C

  exit 0
fi

if [[ "$1" == "show-command-palette" ]]; then
  tmux display-popup -h 53% -w 33% -E "$0 fill-command-palette"
fi

if [[ "$1" == "fill-command-palette" ]]; then
  declare -A tmux_commands=(
    ["Choose Session"]="run-shell '~/bin/tmux-commands.sh choose-session'"
    ["Choose Window in Session"]="choose-tree -wf\"##{==:##{session_name},#{session_name}}\""
    ["Choose Window"]="choose-tree -wZ"
    ["Create New Session"]="command-prompt -p \"New Session:\" \"new-session -A -s '%%'\""
    ["Create New Window"]="new-window -c \"#{pane_current_path}\""
    ["Detach from tmux"]="detach"
    ["Enter Copy Mode"]="copy-mode"
    ["Kill Current Pane"]="confirm-before -p \"Kill pane?\" kill-pane"
    ["Kill Current Window"]="confirm-before -p \"Kill window?\" kill-window"
    ["Kill Session"]="run-shell '~/bin/tmux-commands.sh kill-session'"
    ["Move Pane to New Window"]="break-pane -d"
    ["Open Terminal Popup"]="run-shell '~/bin/tmux-commands.sh popup-terminal'"
    ["Rename Session"]="command-prompt -p \"Rename session:\" \"rename-session '%%'\""
    ["Rename Window"]="command-prompt -p \"Rename window:\" \"rename-window '%%'\""
    ["Split Pane Across Middle"]="split-window -v -c \"#{pane_current_path}\""
    ["Split Pane Down Middle"]="split-window -h -c \"#{pane_current_path}\""
    ["Switch to Last Session"]="switch-client -l"
    ["Switch to Last Window"]="last-window"
  )

  keys=(${(k)tmux_commands})

  selection=$(printf '%s\n' "${keys[@]}" |
    fzf --reverse \
        --layout=reverse \
        --cycle \
        --info=hidden \
        --preview-window=hidden)

  # Exit if no selection was made.
  [[ -z "$selection" ]] && exit 0

  eval "tmux ${tmux_commands[$selection]}"
  exit 0
fi
