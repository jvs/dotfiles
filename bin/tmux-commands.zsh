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


SELF="${0:a}"
TMP_COMMAND_FILE="/tmp/tmux_command_to_run"


# Create zen side panes around the current pane at the given center width.
create_zen_panes() {
  local center_width=${1:-120}
  local total_width=$(tmux display-message -p '#{window_width}')
  local min_total=$(( center_width + 10 ))

  if [[ $total_width -le $min_total ]]; then
    tmux display-message "Terminal too narrow for ${center_width} columns"
    return 1
  fi

  local side_width=$(( (total_width - center_width) / 2 ))
  local center_pane=$(tmux display-message -p '#{pane_id}')

  # Create right pane first (so center pane keeps its ID).
  # Run the zen-clock script so it can display a clock when enabled.
  tmux split-window -h -l $side_width -t "$center_pane" \
    "$SELF zen-clock"
  local right_pane=$(tmux display-message -p '#{pane_id}')
  tmux set-option -p -t "$right_pane" @zen_pane 1

  # Create left pane.
  tmux split-window -hb -l $side_width -t "$center_pane" \
    'read -r -d "" 2>/dev/null || sleep infinity'
  local left_pane=$(tmux display-message -p '#{pane_id}')
  tmux set-option -p -t "$left_pane" @zen_pane 1

  # Style side panes. Left is invisible; right is dim for the clock.
  tmux select-pane -t "$left_pane" -P 'bg=colour234,fg=colour234'
  tmux select-pane -t "$right_pane" -P 'bg=colour234,fg=colour240'

  # Refocus center pane.
  tmux select-pane -t "$center_pane"

  if [[ $center_width -ne 120 ]]; then
    tmux display-message "Zen: ${center_width} columns"
  fi
}



# Check if a window id still exists in the current session.
window_exists() {
  tmux list-windows -F '#{window_id}' | grep -q "^${1}$"
}


if [[ "$1" == "zen-cleanup" ]]; then
  # If all remaining panes in the window are zen panes, kill the window.
  local all_zen=true
  local pane_count=0
  while IFS= read -r line; do
    pane_count=$((pane_count + 1))
    if [[ "${line#*:}" != "1" ]]; then
      all_zen=false
      break
    fi
  done < <(tmux list-panes -F '#{pane_id}:#{@zen_pane}')

  if [[ "$all_zen" == true && $pane_count -gt 0 ]]; then
    tmux kill-window
  fi
  exit 0
fi



if [[ "$1" == "show-menu" ]]; then
  tmux display-menu -T "#[align=centre fg=green] tmux " -x C -y C \
    "Open Supertree"              y "run-shell '$0 show-supertree'" \
    "Open Hometown"               u "run-shell 'hometown show-windows'" \
    "" \
    "Create New Session"          s "command-prompt -p \" New Session:\" \"new-session -A -s '%%'\"" \
    "Choose Session"              p "run-shell '$0 choose-session'" \
    "Choose Window"               t "choose-tree -wZ" \
    "Rename Session"              n "command-prompt -p \" Rename session:\" \"rename-session '%%'\"" \
    "Kill Other Session"          q "run-shell '$0 kill-session'" \
    "" \
    "New Window"                  w "run-shell 'hometown new-window'" \
    "Rename Window"               r "command-prompt -p \" Rename window:\" \"rename-window '%%'\"" \
    "Kill Current Window"         e "run-shell 'hometown kill-window'" \
    "Toggle Zen Mode"             z "run-shell '$0 toggle-zen'" \
    "" \
    "Split Pane Down Middle"      \\ "split-window -h -c \"#{pane_current_path}\"" \
    "Split Pane Across Middle"    -  "split-window -v -c \"#{pane_current_path}\"" \
    "Move Pane to New Window"     o "break-pane -d" \
    "Kill Current Pane"           x "confirm-before -p \" Kill pane?\" kill-pane" \
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
  current_session=$(tmux display-message -p '#S')
  tmux display-popup -h 60% -w 60% -E "$0 kill-session-body '$current_session'"
  exit 0
fi


if [[ $1 == "kill-session-body" ]]; then
  current_session="$2"
  tmux list-sessions -F '#{session_name}' \
  | fzf \
    --reverse -m \
    --header=kill-session \
    --info=hidden \
    --preview 'tmux capture-pane -pt {}' \
  | while IFS= read -r session; do
      if [[ "$session" == "$current_session" ]]; then
        printf ' Kill current session "%s"? [y/N] ' "$current_session" >/dev/tty
        read -r confirm </dev/tty
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          tmux switch-client -l 2>/dev/null || tmux switch-client -n 2>/dev/null
          tmux kill-session -t "$current_session"
        fi
      else
        tmux kill-session -t "$session"
      fi
    done
  exit 0
fi


if [[ $1 == "kill-current-session" ]]; then
  current=$(tmux display-message -p '#S')
  num_sessions=$(tmux list-sessions 2>/dev/null | wc -l | tr -d ' ')
  if [[ $num_sessions -le 1 ]]; then
    tmux display-message "No other sessions to switch to."
    exit 0
  fi
  tmux confirm-before -p " Kill session '$current'?" \
    "run-shell 'tmux switch-client -l 2>/dev/null || tmux switch-client -n; tmux kill-session -t \"$current\"'"
  exit 0
fi


if [[ $1 == "floating-terminal" ]]; then
  local suffix=${2:-"J"}
  local suffix_lower=${suffix:l}
  local popup_session="__popups__"
  local current_session=$(tmux display-message -p '#{session_name}')
  local current_path=$(tmux display-message -p '#{pane_current_path}')

  # If we're already inside the popup session, handle toggle/switch.
  if [[ "$current_session" == "$popup_session" ]]; then
    local current_window_name=$(tmux display-message -p '#W')
    # Window names are popup-{suffix}-{source_session}.
    if [[ "$current_window_name" == popup-${suffix_lower}-* ]]; then
      # Same popup type — close it.
      tmux detach-client
    else
      # Different popup type — switch. Extract source session from window name.
      local source_session=${current_window_name#popup-?-}
      local target_name="popup-${suffix_lower}-${source_session}"
      local target_wid=$(tmux list-windows -t "$popup_session" \
        -F '#{window_id}:#{window_name}' \
        | grep ":${target_name}$" | cut -d':' -f1)
      if [[ -n "$target_wid" ]]; then
        tmux select-window -t "$target_wid"
      else
        tmux new-window -n "$target_name" -c "$current_path"
      fi
    fi
    exit 0
  fi

  # Garbage-collect idle popup windows while we're here.
  $0 popup-gc &>/dev/null &

  local popup_name="popup-${suffix_lower}-${current_session}"

  # Ensure the popup session exists.
  if ! tmux has-session -t "$popup_session" 2>/dev/null; then
    tmux new-session -d -s "$popup_session"
  fi

  # Find or create the popup window in the popup session.
  local popup_wid=$(tmux list-windows -t "$popup_session" \
    -F '#{window_id}:#{window_name}' \
    | grep ":${popup_name}$" | cut -d':' -f1)

  if [[ -z "$popup_wid" ]]; then
    tmux new-window -d -t "$popup_session" -n "$popup_name" -c "$current_path"
    popup_wid=$(tmux list-windows -t "$popup_session" \
      -F '#{window_id}:#{window_name}' \
      | grep ":${popup_name}$" | cut -d':' -f1)
  fi

  # Terminal J syncs cwd to the underlying window (if shell is idle).
  if [[ "$suffix_lower" == "j" ]]; then
    local popup_cmd=$(tmux display-message -t "$popup_wid" -p '#{pane_current_command}')
    local popup_path=$(tmux display-message -t "$popup_wid" -p '#{pane_current_path}')
    if [[ ("$popup_cmd" == "zsh" || "$popup_cmd" == "bash") && "$popup_path" != "$current_path" ]]; then
      tmux send-keys -t "$popup_wid" " cd $(printf '%q' "$current_path")" Enter
    fi
  fi

  # Popup dimensions.
  local popup_height="80%"
  local popup_width="80%"
  local original_height=$(tmux display-message -p '#{client_height}')
  local original_width=$(tmux display-message -p '#{client_width}')
  local popup_height_chars=$(( original_height * 80 / 100 ))
  local popup_width_chars=$(( original_width * 80 / 100 ))

  tmux resize-window -t "$popup_wid" -x $popup_width_chars -y $popup_height_chars

  tmux set-option -t "$popup_session" @popup_is_overlay 1
  tmux display-popup -h $popup_height -w $popup_width \
    -T "#[align=right fg=yellow] Terminal $suffix " \
    -EE "tmux attach-session -t '${popup_session}:${popup_wid}'"
  tmux set-option -t "$popup_session" -u @popup_is_overlay 2>/dev/null

  # If the popup signaled "expand", switch to the popup session full-screen.
  local expand=$(tmux show-option -qv -t "$popup_session" @popup_expand 2>/dev/null)
  if [[ "$expand" == "1" ]]; then
    tmux set-option -t "$popup_session" -u @popup_expand
    tmux switch-client -t "$popup_session"
  fi

  exit 0
fi


if [[ "$1" == "expand-popup" ]]; then
  local popup_session="__popups__"
  local current_session=$(tmux display-message -p '#{session_name}')

  if [[ "$current_session" == "$popup_session" ]]; then
    # We're in the popup session. Distinguish overlay vs. full-screen using
    # @popup_is_overlay, which floating-terminal sets before display-popup
    # and clears after it returns.
    local is_overlay=$(tmux show-option -qv -t "$popup_session" @popup_is_overlay 2>/dev/null)
    if [[ "$is_overlay" == "1" ]]; then
      # Inside a popup overlay — signal expand and detach.
      tmux set-option -t "$popup_session" @popup_expand 1
      tmux detach-client
    else
      # Full-screen in the popup session — go back to previous session.
      tmux switch-client -l
    fi
  elif tmux has-session -t "$popup_session" 2>/dev/null; then
    # Normal session, no popup open — switch to popup session directly.
    tmux switch-client -t "$popup_session"
  fi
  exit 0
fi


if [[ "$1" == "popup-cleanup" ]]; then
  # Kill all popup windows belonging to a specific session.
  local target_session="$2"
  local popup_session="__popups__"

  if ! tmux has-session -t "$popup_session" 2>/dev/null; then
    exit 0
  fi

  local windows_to_kill=()
  while IFS= read -r line; do
    local wid=${line%%:*}
    local wname=${line#*:}
    if [[ "$wname" == popup-*-${target_session} ]]; then
      windows_to_kill+=("$wid")
    fi
  done < <(tmux list-windows -t "$popup_session" -F '#{window_id}:#{window_name}')

  for wid in "${windows_to_kill[@]}"; do
    tmux kill-window -t "$wid"
  done

  # If the popup session is now empty, kill it too.
  local remaining=$(tmux list-windows -t "$popup_session" 2>/dev/null | wc -l)
  if [[ "$remaining" -eq 0 ]]; then
    tmux kill-session -t "$popup_session" 2>/dev/null
  fi
  exit 0
fi


if [[ "$1" == "popup-gc" ]]; then
  # Kill idle popup windows (shell idle for over 3 hours).
  local popup_session="__popups__"
  local max_idle=10800  # 3 hours in seconds

  if ! tmux has-session -t "$popup_session" 2>/dev/null; then
    exit 0
  fi

  while IFS= read -r line; do
    local wid=${line%%|*}
    local rest=${line#*|}
    local cmd=${rest%%|*}
    local idle=${rest#*|}

    # Only kill if the shell is idle (not running a command).
    if [[ ("$cmd" == "zsh" || "$cmd" == "bash") && "$idle" -gt "$max_idle" ]]; then
      tmux kill-window -t "$wid"
    fi
  done < <(tmux list-windows -t "$popup_session" \
    -F '#{window_id}|#{pane_current_command}|#{pane_idle}')

  # If the popup session is now empty, kill it too.
  local remaining=$(tmux list-windows -t "$popup_session" 2>/dev/null | wc -l)
  if [[ "$remaining" -eq 0 ]]; then
    tmux kill-session -t "$popup_session" 2>/dev/null
  fi
  exit 0
fi


if [[ "$1" == "toggle-zen" ]]; then
  # Check if zen panes exist in the current window.
  local zen_panes=($(tmux list-panes -F '#{pane_id}:#{@zen_pane}' \
    | grep ':1$' | cut -d':' -f1))

  if [[ ${#zen_panes[@]} -gt 0 ]]; then
    # Exit zen: kill the zen side panes.
    for pid in "${zen_panes[@]}"; do
      tmux kill-pane -t "$pid"
    done
  else
    # Enter zen: create side panes.
    create_zen_panes 120
  fi
  exit 0
fi


if [[ "$1" == "resize-zen" ]]; then
  if [[ -n "$2" ]]; then
    # Called with a width argument.
    local new_width="$2"

    # Exit existing zen first.
    local zen_panes=($(tmux list-panes -F '#{pane_id}:#{@zen_pane}' \
      | grep ':1$' | cut -d':' -f1))
    for pid in "${zen_panes[@]}"; do
      tmux kill-pane -t "$pid"
    done

    create_zen_panes "$new_width"
  else
    # No argument — show a prompt with the current width.
    local current_width=$(tmux display-message -p '#{pane_width}')
    tmux command-prompt -p " Zen width (current: ${current_width}):" \
      "run-shell '#{@tmux_commands} resize-zen %%'"
  fi
  exit 0
fi


if [[ "$1" == "zen-clock" ]]; then
  # Runs inside the right zen pane. Loops and displays the time based on
  # the @zen_clock session option (off, local, world).
  local last_drawn=""

  while true; do
    local style=$(tmux show-option -qv @zen_clock 2>/dev/null)
    style=${style:-off}
    local now=$(date +%H:%M)
    local key="${style}:${now}"

    # Only redraw when something changes.
    if [[ "$key" != "$last_drawn" ]]; then
      last_drawn="$key"
      printf '\033[2J\033[H'  # Clear screen, cursor to top.

      case "$style" in
        local)
          printf '\n\n  %s\n' "$(date '+%I:%M %p')"
          ;;
        world)
          printf '\n\n'
          printf '  %-10s %s\n' "Chicago" "$(TZ='America/Chicago' date '+%I:%M %p')"
          printf '  %s\n' "───────────────────"
          printf '  %-10s %s\n' "New York" "$(TZ='America/New_York' date '+%I:%M %p')"
          printf '  %-10s %s\n' "London" "$(TZ='Europe/London' date '+%I:%M %p')"
          printf '  %-10s %s\n' "Poland" "$(TZ='Europe/Warsaw' date '+%I:%M %p')"
          printf '  %-10s %s\n' "UTC" "$(TZ='UTC' date '+%I:%M %p')"
          ;;
      esac
    fi

    # Sleep in short intervals so style changes take effect quickly.
    sleep 5
  done
fi


if [[ "$1" == "cycle-zen-clock" ]]; then
  local style=$(tmux show-option -qv @zen_clock 2>/dev/null)
  case "$style" in
    local) tmux set-option @zen_clock world;  tmux display-message "Zen clock: world" ;;
    world) tmux set-option @zen_clock off;    tmux display-message "Zen clock: off" ;;
    *)     tmux set-option @zen_clock local;  tmux display-message "Zen clock: local" ;;
  esac
  exit 0
fi


check_tmux_command_file() {
  if [[ -f "$TMP_COMMAND_FILE" ]]; then
    cmd=$(cat "$TMP_COMMAND_FILE")
    rm -rf "$TMP_COMMAND_FILE"
    eval "$cmd"
  fi

  exit 0
}


if [[ "$1" == "show-command-palette" ]]; then
  tmux display-popup -h 53% -w 33% -E "$0 show-command-palette-body"
  check_tmux_command_file
  exit 0
fi


if [[ "$1" == "show-command-palette-body" ]]; then
  declare -A tmux_commands=(
    # Sessions.
    ["Open Supertree"]="run-shell '$0 show-supertree'"
    ["Open Hometown"]="run-shell 'hometown show-windows'"
    ["Create New Session"]="run-shell '$0 create-new-session'"
    ["Choose Session"]="run-shell '$0 choose-session'"
    ["Kill Current Session"]="run-shell '$0 kill-current-session'"
    ["Kill Other Session"]="run-shell '$0 kill-session'"
    ["Rename Session"]="command-prompt -p \" Rename session:\" \"rename-session '%%'\""
    ["Switch to Last Session"]="switch-client -l"

    # Windows.
    ["Choose Window"]="choose-tree -wZ"
    ["Kill Current Window"]="run-shell 'hometown kill-window'"
    ["Maximize Window"]="resize-window -A"
    ["Rename Window"]="command-prompt -p \" Rename window:\" \"rename-window '%%'\""

    # Panes.
    ["Kill Current Pane"]="confirm-before -p \" Kill pane?\" kill-pane"
    ["Move Pane to New Window"]="break-pane -d"
    ["Split Pane Across Middle"]="split-window -v -c \"#{pane_current_path}\""
    ["Split Pane Down Middle"]="split-window -h -c \"#{pane_current_path}\""
    ["Toggle Zen Mode"]="run-shell '$0 toggle-zen'"
    ["Resize Zen Mode"]="run-shell '$0 resize-zen'"
    ["Cycle Zen Clock"]="run-shell '$0 cycle-zen-clock'"

    # Utilities.
    ["Display Clock"]="clock-mode"
    ["Toggle Floating Terminal J"]="run-shell '$0 floating-terminal J'"
    ["Toggle Floating Terminal K"]="run-shell '$0 floating-terminal K'"
    ["Expand/Collapse Popup"]="run-shell '$0 expand-popup'"
    ["Show World Time"]="display-popup -h 11 -w 29 \
      -T '#[align=centre fg=green] World Time ' \
      -E '$0 show-world-time && read -n 1'"

    # tmux.
    ["Detach All Other Clients"]="run-shell 'tmux detach-client -a'"
    ["Detach from tmux"]="detach"
    ["Enter Copy Mode"]="copy-mode"
    ["Reload tmux Configuration"]="source-file ~/.tmux.conf \; display-message \"Reloaded ~/tmux.conf\""
    ["Show Command Prompt"]="command-prompt -p ' Command:'"
    ["Show Messages"]="show-messages"
    ["Toggle Status Bar"]="set -g status"
    ["Kill Server"]="confirm-before -p ' Kill tmux server?' kill-server"
    ["Show Client Info"]="display-popup -E -h 19 -w 50 '$0 show-client-info && read -n 1'"
  )

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
  echo "tmux ${tmux_commands[$selection]}" > "$TMP_COMMAND_FILE"
  exit 0
fi


if [[ "$1" == "show-world-time" ]]; then
    echo ""
    echo "   Chicago:    $(TZ="America/Chicago" date "+%I:%M %p")"
    echo "   New York:   $(TZ="America/New_York" date "+%I:%M %p")"
    echo "   London:     $(TZ="Europe/London" date "+%I:%M %p")"
    echo "   Poland:     $(TZ="Europe/Warsaw" date "+%I:%M %p")"
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

  # TODO: Ask hometown for the current lane.
  # current_lane=$(get_current_lane)
  # current_lane_display=${current_lane:-"(none)"}
  # [[ "$current_lane" == "semi" ]] && current_lane_display=";"

  echo "\nSession info:"
  echo "-----------------------------------------------"
  echo "Session:   $current_session"
  # echo "Lane:      ${current_lane_display:u}"
  echo "Window:    $current_window"
  echo "Pane:      $current_pane"
  echo "Path:      $current_path"

  echo "\n[Press any key]"
fi


if [[ "$1" == "create-new-session" ]]; then
  # For some reason, tmux makes this really difficult. I don't know why it's
  # so much easier from the display-menu.
  if [[ -z "$2" ]]; then
    tmux command-prompt -p " New Session:" "run-shell '$0 create-new-session \"%%\"'"
    exit 0
  fi

  tmux new-session -d -s "$2" -c "#{pane_current_path}"
  tmux switch-client -t "$2"
  exit 0
fi


function get_max_length() {
  local max=0
  local length=0

  while read -r line; do
    length=${#line}
    if (( length > max )); then
      max=$length
    fi
  done

  echo $max
}


if [[ "$1" == "show-supertree" ]]; then
  session_count=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep -cv '^__')
  window_count=$(tmux list-windows -a -F "#{session_name}" 2>/dev/null | grep -cv '^__')
  total_count=$((session_count + window_count))
  total_height=$((total_count + 4))

  longest_session_name=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | get_max_length)
  longest_window_name=$(tmux list-windows -a -F "#{window_name}" 2>/dev/null | get_max_length)
  if (( longest_session_name > longest_window_name )); then
    longest_name=$((longest_session_name + 3))
  else
    longest_name=$((longest_window_name + 3))
  fi

  if (( longest_name < 24 )); then
    longest_name=24
  fi

  total_width=$((longest_name + 6))

  tmux display-popup -h "$total_height" -w "$total_width" \
    -b rounded \
    -T "#[align=centre fg=white] supertree " \
    -EE "$0 show-supertree-body"

  check_tmux_command_file
fi


if [[ "$1" == "show-supertree-body" ]]; then

  if [ -d "${HOME}/github/jvs/tmux-supertree" ]; then
    SUPERTREE_DIR="${HOME}/github/jvs/tmux-supertree"
  else
    SCRIPT_PATH="$0"
    if [ -L "$SCRIPT_PATH" ]; then
      REAL_PATH=$(readlink -f "$SCRIPT_PATH")
    else
      REAL_PATH="$SCRIPT_PATH"
    fi

    BIN_DIR=$(dirname "$REAL_PATH")
    SUPERTREE_DIR="$BIN_DIR/../runtime/tmux-supertree"
  fi

  "${SUPERTREE_DIR}/supertree" \
    --command-file "$TMP_COMMAND_FILE" \
    --return-command "$0 show-supertree" \
    --switch-command "hometown show-windows"
fi
