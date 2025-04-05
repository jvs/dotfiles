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
    "Choose Session"              p "run-shell '$0 choose-session'" \
    "Choose Window"               t "choose-tree -wZ" \
    "Switch to Last Session"      h "switch-client -l" \
    "Rename Session"              n "command-prompt -p \"Rename session:\" \"rename-session '%%'\"" \
    "Kill Session"                q "run-shell '$0 kill-session'" \
    "" \
    "Create New Window"           w "new-window -c \"#{pane_current_path}\"" \
    "Choose Window in Session"    c "choose-tree -wf\"##{==:##{session_name},#{session_name}}\"" \
    "Open Window Menu"            o "run-shell '$0 show-window-menu'" \
    "Switch to Last Window"       l "last-window" \
    "Toggle Floating Terminal"    g "run-shell '$0 floating-terminal'" \
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
      --info=hidden \
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
      --info=hidden \
      --preview 'tmux capture-pane -pt {}' \
    | xargs -I {} tmux kill-session -t {}"

  exit 0
fi


if [[ $1 == "floating-terminal" ]]; then
  floating_session="floating-terminal"
  current_session=$(tmux display-message -p '#S')

  terminal_window_suffix=${2:-"J"}
  terminal_window_name="terminal-$terminal_window_suffix"

  if [ "$current_session" = "$floating_session" ]; then
    current_window=$(tmux display-message -p '#W')

    tmux detach-client
    tmux kill-session -t "floating-terminal"

    if [ "$current_window" = "$terminal_window_name" ]; then
      exit 0
    else
      "$0" floating-terminal "$terminal_window_suffix"
      exit $?
    fi
  fi

  terminal_window_exists=$(tmux list-windows -F '#{window_name}' \
    | grep -c "^$terminal_window_name$")

  # Check the current session for the floating terminal window.
  terminal_window_suffix=${2:-"J"}
  terminal_window_name="terminal-$terminal_window_suffix"
  terminal_window_exists=$(tmux list-windows -F '#{window_name}' \
    | grep -c "^$terminal_window_name$")

  # Create the terminal window if it doesn't exist.
  if [ "$terminal_window_exists" -eq 0 ]; then
    current_path=$(tmux display-message -p '#{pane_current_path}')
    tmux new-window -d -n "$terminal_window_name" -t "$current_session" -c "$current_path"
  fi

  popup_height="80%"
  popup_width="80%"

  # Save the original terminal size
  original_height=$(tmux display-message -p '#{client_height}')
  original_width=$(tmux display-message -p '#{client_width}')

  # Calculate the popup size in characters
  popup_height_chars=$(( $original_height * 80 / 100 ))
  popup_width_chars=$(( $original_width * 80 / 100 ))

  tmux resize-window -t "$terminal_window_name" -x $popup_width_chars -y $popup_height_chars

  # Get the index of the terminal window.
  terminal_window_index=$(tmux list-windows -F '#I:#W' \
    | grep ":$terminal_window_name$" | cut -d':' -f1)

  # See if we have a floating terminal session.
  floating_session_exists=$(tmux list-sessions -F '#{session_name}' \
    | grep -c "^$floating_session$")

  # Create the floating terminal session if it doesn't exist.
  if [ "$floating_session_exists" -eq 0 ]; then
    tmux new-session -d -s "$floating_session"
  fi

  # Link the terminal window to the floating session.
  tmux link-window -s "$current_session:$terminal_window_index" -t "$floating_session"

  tmux display-popup -h $popup_height -w $popup_width -EE "\
    tmux attach-session -t $floating_session:$terminal_window_name"
  exit 0
fi


if [[ "$1" == "show-command-palette" ]]; then
  tmux display-popup -h 53% -w 33% -E "$0 show-command-palette-body"

  cmd=$(cat /tmp/tmux_command_to_run)
  rm -rf /tmp/tmux_command_to_run
  eval "tmux $cmd"
fi


if [[ "$1" == "show-command-palette-body" ]]; then
  declare -A tmux_commands=(
    # Sessions.
    ["Create New Session"]="command-prompt -p \"New Session:\" \"new-session -A -s '%%'\""
    ["Choose Session"]="run-shell '$0 choose-session'"
    ["Kill Other Session"]="run-shell '$0 kill-session'"
    ["Rename Session"]="command-prompt -p \"Rename session:\" \"rename-session '%%'\""
    ["Switch to Last Session"]="switch-client -l"

    # Windows.
    ["Choose Window in Current Session"]="choose-tree -wf\"##{==:##{session_name},#{session_name}}\""
    ["Choose Window"]="choose-tree -wZ"
    ["Create New Window"]="new-window -c \"#{pane_current_path}\""
    ["Maximize Window"]="resize-window -A"
    ["Open Window Menu"]="run-shell '$0 show-window-menu'"
    ["Kill Current Window"]="confirm-before -p \"Kill window?\" kill-window"
    ["Rename Window"]="command-prompt -p \"Rename window:\" \"rename-window '%%'\""
    ["Switch to Last Window"]="last-window"

    # Panes.
    ["Kill Current Pane"]="confirm-before -p \"Kill pane?\" kill-pane"
    ["Move Pane to New Window"]="break-pane -d"
    ["Split Pane Across Middle"]="split-window -v -c \"#{pane_current_path}\""
    ["Split Pane Down Middle"]="split-window -h -c \"#{pane_current_path}\""

    # Utilities.
    ["Display Clock"]="clock-mode"
    ["Toggle Floating Terminal"]="run-shell '$0 floating-terminal'"
    ["Show World Time"]="display-popup -h 11 -w 29 -E '$0 show-world-time && read -n 1'"

    # tmux.
    ["Detach from tmux"]="detach"
    ["Enter Copy Mode"]="copy-mode"
    ["Reload tmux Configuration"]="source-file ~/.tmux.conf \; display-message \"Reloaded ~/tmux.conf\""
    ["Show Command Prompt"]="command-prompt -p 'Command:'"
    ["Toggle Status Bar"]="set -g status"
    ["Show Client Info"]="display-popup -E -h 18 -w 50 '$0 show-client-info && read -n 1'"
  )

  keys=(${(k)tmux_commands})
  keys=(${(i)${(k)tmux_commands}})

  selection=$(printf '%s\n' "${keys[@]}" |
    fzf --reverse \
        --layout=reverse \
        --cycle \
        --info=hidden \
        --preview-window=hidden)

  # Exit if no selection was made.
  [[ -z "$selection" ]] && exit 0

  # Write the selected command to a temporary file.
  echo "${tmux_commands[$selection]}" > /tmp/tmux_command_to_run
  exit 0
fi


if [[ "$1" == "show-window-menu" ]]; then
  tmux list-windows -F '#I #W' \
    | awk 'BEGIN {ORS=" "} {print $2, NR, "\"select-window -t", $1 "\""}' \
    | xargs tmux display-menu -T "#[align=centre fg=green] tmux " -x C -y C

  exit 0
fi


if [[ "$1" == "show-world-time" ]]; then
    echo "   World Time"
    echo "   --------------------"
    echo "   Chicago:    $(TZ="America/Chicago" date "+%I:%M %p")"
    echo "   New York:   $(TZ="America/New_York" date "+%I:%M %p")"
    echo "   London:     $(TZ="Europe/London" date "+%I:%M %p")"
    echo "   UTC:        $(TZ="UTC" date "+%I:%M %p")"
    echo "\n     [Press any key]"
fi


if [[ "$1" == "show-client-info" ]]; then
  current_client=$(tmux display-message -p '#{client_name}')
  current_pid=$(tmux display-message -p '#{client_pid}')
  current_terminal=$(tmux display-message -p '#{client_termname}')
  current_session=$(tmux display-message -p '#S')
  current_window=$(tmux display-message -p '#W')
  current_pane=$(tmux display-message -p '#P')
  current_path=$(tmux display-message -p '#{pane_current_path}')
  current_size=$(tmux display-message -p '#{client_width}x#{client_height}')

  echo "Client info:"
  echo "-----------------------------------------------"
  echo "Client:    $current_client"
  echo "PID:       $current_pid"
  echo "Terminal:  $current_terminal"
  echo "Size:      $current_size"

  echo "\nSession info:"
  echo "-----------------------------------------------"
  echo "Session:   $current_session"
  echo "Window:    $current_window"
  echo "Pane:      $current_pane"
  echo "Path:      $current_path"

  echo "\n[Press any key]"
fi
