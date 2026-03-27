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


# ---------------------------------------------------------------------------
# Lane helpers
# ---------------------------------------------------------------------------

# Get the current lane from the active window's @lane tag.
get_current_lane() {
  local lane=$(tmux show-option -wqv @lane)
  echo "${lane:-j}"
}

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

ensure_lanes() {
  local initialized=$(tmux show-option -qv @lane_initialized)
  if [[ "$initialized" == "1" ]]; then
    return 0
  fi

  # Tag every existing window with lane "j".
  local win_ids=($(tmux list-windows -F '#{window_id}'))
  for wid in "${win_ids[@]}"; do
    tmux set-option -w -t "$wid" @lane j
  done

  # Record the current window as lane-j's last window.
  local cur_wid=$(tmux display-message -p '#{window_id}')
  tmux set-option @lane_j_window "$cur_wid"
  tmux set-option @prev_lane j
  tmux set-option @lane_initialized 1

  # Hook: auto-tag new windows with the current lane.
  tmux set-hook -t "$(tmux display-message -p '#{session_name}')" \
    after-new-window \
    "run-shell '#{@tmux_commands} tag-new-window'"

  # Hook: kill window if only zen panes remain after a pane exits.
  tmux set-hook -t "$(tmux display-message -p '#{session_name}')" \
    pane-exited \
    "run-shell '#{@tmux_commands} zen-cleanup'"
}


# Tag a newly created window with the current lane (called by hook).
# The new window is already active, so we get the lane from the previous window.
tag_new_window() {
  local existing=$(tmux show-option -wqv @lane)
  if [[ -z "$existing" ]]; then
    local lane=$(tmux show-option -wqv -t '{last}' @lane 2>/dev/null)
    tmux set-option -w @lane "${lane:-j}"
  fi
}


# Adopt any untagged windows into lane-j.
adopt_orphan_windows() {
  while IFS= read -r line; do
    local wid=${line%%:*}
    local wlane=${line#*:}
    if [[ -z "$wlane" ]]; then
      tmux set-option -w -t "$wid" @lane j
    fi
  done < <(tmux list-windows -F '#{window_id}:#{@lane}')
}


# Check if a window id still exists in the current session.
window_exists() {
  tmux list-windows -F '#{window_id}' | grep -q "^${1}$"
}


if [[ "$1" == "tag-new-window" ]]; then
  tag_new_window
  exit 0
fi


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


if [[ "$1" == "switch-lane" ]]; then
  ensure_lanes
  adopt_orphan_windows
  target="$2"
  current_lane=$(get_current_lane)
  current_wid=$(tmux display-message -p '#{window_id}')

  # Save the current window for the current lane.
  tmux set-option "@lane_${current_lane}_window" "$current_wid"

  if [[ "$target" == "$current_lane" ]]; then
    # Already in this lane — just confirm.
    local display_lane=${target}
    [[ "$target" == "semi" ]] && display_lane=";"
    tmux display-message "[ Lane ${display_lane:u} ]"
    exit 0
  fi

  # Update lane tracking.
  tmux set-option @prev_lane "$current_lane"

  # Try to switch to the target lane's last window.
  local target_wid=$(tmux show-option -qv "@lane_${target}_window")

  if [[ -n "$target_wid" ]] && window_exists "$target_wid"; then
    tmux select-window -t "$target_wid"
  else
    # No window in this lane yet — create one.
    tmux new-window -c "#{pane_current_path}"
    local new_wid=$(tmux display-message -p '#{window_id}')
    tmux set-option -w @lane "$target"
    tmux set-option "@lane_${target}_window" "$new_wid"
  fi
  exit 0
fi


if [[ "$1" == "flashback" ]]; then
  ensure_lanes
  adopt_orphan_windows
  local current_lane=$(get_current_lane)
  local current_wid=$(tmux display-message -p '#{window_id}')
  local prev_lane=$(tmux show-option -qv @prev_lane)

  if [[ -z "$prev_lane" || "$prev_lane" == "$current_lane" ]]; then
    tmux display-message "No previous lane"
    exit 0
  fi

  # Save the current window for the current lane.
  tmux set-option "@lane_${current_lane}_window" "$current_wid"

  # Update lane tracking.
  tmux set-option @prev_lane "$current_lane"

  # Show lane indicator.
  local display_lane=${prev_lane}
  [[ "$prev_lane" == "semi" ]] && display_lane=";"
  tmux display-message "[ Lane ${display_lane:u} ]"

  # Switch to the previous lane's last window.
  local target_wid=$(tmux show-option -qv "@lane_${prev_lane}_window")
  if [[ -n "$target_wid" ]] && window_exists "$target_wid"; then
    tmux select-window -t "$target_wid"
  else
    tmux new-window -c "#{pane_current_path}"
    local new_wid=$(tmux display-message -p '#{window_id}')
    tmux set-option -w @lane "$prev_lane"
    tmux set-option "@lane_${prev_lane}_window" "$new_wid"
  fi
  exit 0
fi


if [[ "$1" == "lane-next-window" ]]; then
  ensure_lanes
  adopt_orphan_windows
  local current_lane=$(get_current_lane)
  local current_wid=$(tmux display-message -p '#{window_id}')

  # Get all window IDs in this lane, ordered by index.
  local lane_windows=()
  while IFS= read -r line; do
    local wid=${line%%:*}
    local wlane=${line#*:}
    if [[ "$wlane" == "$current_lane" ]]; then
      lane_windows+=("$wid")
    fi
  done < <(tmux list-windows -F '#{window_id}:#{@lane}')

  if [[ ${#lane_windows[@]} -le 1 ]]; then
    exit 0
  fi

  # Find current position and go to next.
  local idx=0
  for ((i = 1; i <= ${#lane_windows[@]}; i++)); do
    if [[ "${lane_windows[$i]}" == "$current_wid" ]]; then
      idx=$i
      break
    fi
  done

  local next_idx=$(( idx % ${#lane_windows[@]} + 1 ))
  local next_wid="${lane_windows[$next_idx]}"
  tmux select-window -t "$next_wid"
  tmux set-option "@lane_${current_lane}_window" "$next_wid"
  exit 0
fi


if [[ "$1" == "lane-prev-window" ]]; then
  ensure_lanes
  adopt_orphan_windows
  local current_lane=$(get_current_lane)
  local current_wid=$(tmux display-message -p '#{window_id}')

  local lane_windows=()
  while IFS= read -r line; do
    local wid=${line%%:*}
    local wlane=${line#*:}
    if [[ "$wlane" == "$current_lane" ]]; then
      lane_windows+=("$wid")
    fi
  done < <(tmux list-windows -F '#{window_id}:#{@lane}')

  if [[ ${#lane_windows[@]} -le 1 ]]; then
    exit 0
  fi

  local idx=0
  for ((i = 1; i <= ${#lane_windows[@]}; i++)); do
    if [[ "${lane_windows[$i]}" == "$current_wid" ]]; then
      idx=$i
      break
    fi
  done

  local prev_idx=$(( (idx - 2 + ${#lane_windows[@]}) % ${#lane_windows[@]} + 1 ))
  local prev_wid="${lane_windows[$prev_idx]}"
  tmux select-window -t "$prev_wid"
  tmux set-option "@lane_${current_lane}_window" "$prev_wid"
  exit 0
fi


if [[ "$1" == "lane-new-window" ]]; then
  ensure_lanes
  local current_lane=$(get_current_lane)
  tmux new-window -c "#{pane_current_path}"
  local new_wid=$(tmux display-message -p '#{window_id}')
  tmux set-option -w @lane "$current_lane"
  tmux set-option "@lane_${current_lane}_window" "$new_wid"
  exit 0
fi


if [[ "$1" == "lane-kill-window" ]]; then
  ensure_lanes
  local current_lane=$(get_current_lane)
  local current_wid=$(tmux display-message -p '#{window_id}')

  # Find another window in the same lane to land on after kill.
  local fallback_wid=""
  while IFS= read -r line; do
    local wid=${line%%:*}
    local wlane=${line#*:}
    if [[ "$wlane" == "$current_lane" && "$wid" != "$current_wid" ]]; then
      fallback_wid="$wid"
      break
    fi
  done < <(tmux list-windows -F '#{window_id}:#{@lane}')

  # Use confirm-before so user can cancel.
  if [[ -n "$fallback_wid" ]]; then
    tmux confirm-before -p " Kill window?" \
      "kill-window; select-window -t $fallback_wid; set-option @lane_${current_lane}_window $fallback_wid"
  else
    # Last window in this lane — after kill, switch to lane-j.
    tmux confirm-before -p " Kill window? (last in lane)" \
      "kill-window; run-shell '#{@tmux_commands} switch-lane j'"
  fi
  exit 0
fi


if [[ "$1" == "move-window-to-lane" ]]; then
  ensure_lanes
  tmux display-menu -T "#[align=centre fg=yellow] Move to Lane " -x C -y C \
    "H  (lane H)" h "run-shell '#{@tmux_commands} move-window-to-lane-exec h'" \
    "J  (lane J)" j "run-shell '#{@tmux_commands} move-window-to-lane-exec j'" \
    "K  (lane K)" k "run-shell '#{@tmux_commands} move-window-to-lane-exec k'" \
    "L  (lane L)" l "run-shell '#{@tmux_commands} move-window-to-lane-exec l'" \
    ";  (lane ;)" ";" "run-shell '#{@tmux_commands} move-window-to-lane-exec semi'"
  exit 0
fi


if [[ "$1" == "move-window-to-lane-exec" ]]; then
  ensure_lanes
  local target_lane="$2"
  local current_wid=$(tmux display-message -p '#{window_id}')
  local old_lane=$(tmux show-option -wqv @lane)

  # Clear the old lane's stored window if it pointed to this window.
  if [[ -n "$old_lane" ]]; then
    local old_stored=$(tmux show-option -qv "@lane_${old_lane}_window")
    if [[ "$old_stored" == "$current_wid" ]]; then
      tmux set-option -u "@lane_${old_lane}_window"
    fi
  fi

  tmux set-option -w @lane "$target_lane"
  tmux display-message "Moved window to lane $target_lane"
  exit 0
fi


if [[ "$1" == "show-menu" ]]; then
  tmux display-menu -T "#[align=centre fg=green] tmux " -x C -y C \
    "Open Supertree"              u "run-shell '$0 show-supertree'" \
    "Create New Session"          s "command-prompt -p \" New Session:\" \"new-session -A -s '%%'\"" \
    "Choose Session"              p "run-shell '$0 choose-session'" \
    "Choose Window"               t "choose-tree -wZ" \
    "Rename Session"              n "command-prompt -p \" Rename session:\" \"rename-session '%%'\"" \
    "Kill Other Session"          q "run-shell '$0 kill-session'" \
    "" \
    "New Window in Lane"          w "run-shell '$0 lane-new-window'" \
    "Move Window to Lane"         m "run-shell '$0 move-window-to-lane'" \
    "Rename Window"               r "command-prompt -p \" Rename window:\" \"rename-window '%%'\"" \
    "Kill Current Window"         e "run-shell '$0 lane-kill-window'" \
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

  tmux display-popup -h $popup_height -w $popup_width \
    -T "#[align=right fg=yellow] Terminal $suffix " \
    -EE "tmux attach-session -t '${popup_session}:${popup_wid}'"

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
    # We're in the popup session. Could be inside a popup overlay or full-screen.
    # Either way, check if we're in an overlay (inner client) by looking at
    # whether the outer client is blocking on display-popup. The simplest
    # signal: set the expand flag and detach. If we're already full-screen
    # (not in an overlay), detach would close our connection, so instead
    # just switch back.
    #
    # Heuristic: if there are multiple clients on the popup session, we're
    # likely in an overlay (the outer display-popup holds one client).
    local client_count=$(tmux list-clients -t "$popup_session" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$client_count" -gt 1 ]]; then
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
    ["Create New Session"]="run-shell '$0 create-new-session'"
    ["Choose Session"]="run-shell '$0 choose-session'"
    ["Kill Other Session"]="run-shell '$0 kill-session'"
    ["Rename Session"]="command-prompt -p \" Rename session:\" \"rename-session '%%'\""
    ["Switch to Last Session"]="switch-client -l"

    # Windows / Lanes.
    ["Choose Window"]="choose-tree -wZ"
    ["Create New Window in Lane"]="run-shell '$0 lane-new-window'"
    ["Kill Current Window"]="run-shell '$0 lane-kill-window'"
    ["Maximize Window"]="resize-window -A"
    ["Move Window to Another Lane"]="run-shell '$0 move-window-to-lane'"
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


if [[ "$1" == "show-window-menu" ]]; then
  tmux list-windows -F '#I #W' \
    | awk 'BEGIN {ORS=" "} {print $2, NR, "\"select-window -t", $1 "\""}' \
    | xargs tmux display-menu -T "#[align=centre fg=green] tmux " -x C -y C

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

  current_lane=$(get_current_lane)
  current_lane_display=${current_lane:-"(none)"}
  [[ "$current_lane" == "semi" ]] && current_lane_display=";"

  echo "\nSession info:"
  echo "-----------------------------------------------"
  echo "Session:   $current_session"
  echo "Lane:      ${current_lane_display:u}"
  echo "Window:    $current_window"
  echo "Pane:      $current_pane"
  echo "Path:      $current_path"

  echo "\n[Press any key]"
fi


# Function to move a window from one index to another
move_window_index() {
  local session="$1"
  local source_index="$2"
  local target_index="$3"
  local direction="$4"

  # Validate inputs.
  if [[ -z "$session" || -z "$source_index" || -z "$target_index" ]]; then
    echo "Error: Missing parameters (session, source_index, target_index)" >&2
    return 1
  fi

  # Check if source window exists.
  if ! tmux list-windows -t "$session" -F '#I' | grep -q "^${source_index}$"; then
    echo "Error: Source window $source_index does not exist in session $session" >&2
    return 1
  fi

  # If source and target are the same, nothing to do.
  if [[ "$source_index" -eq "$target_index" ]]; then
    return 0
  fi

  # Get a sorted list of window indices.
  local window_indexes=($(tmux list-windows -t "$session" -F '#I' | sort -n))

  # Find the positions of the source and target windows.
  local source_array_index=0
  for idx in "${window_indexes[@]}"; do
    source_array_index=$((source_array_index + 1))
    if [[ "$idx" -eq "$source_index" ]]; then
      break
    fi
  done

  local target_array_index=0
  for idx in "${window_indexes[@]}"; do
    target_array_index=$((target_array_index + 1))
    if [[ "$idx" -eq "$target_index" ]]; then
      break
    fi
  done

  if [[ "$source_array_index" -gt "$target_array_index" && "$direction" == "down" ]]; then
    target_array_index=$(( target_array_index + 1 ))
  fi

  if [[ "$source_array_index" -lt "$target_array_index" && "$direction" == "up" ]]; then
    target_array_index=$(( target_array_index - 1 ))
  fi

  local next_array_index=0
  while [[ "$source_array_index" -ne "$target_array_index" ]]; do
    if [[ "$source_array_index" -lt "$target_array_index" ]]; then
      next_array_index=$((source_array_index + 1))
    else
      next_array_index=$((source_array_index - 1))
    fi

    tmux swap-window \
      -s "$session:${window_indexes[source_array_index]}" \
      -t "$session:${window_indexes[next_array_index]}"

    source_array_index="$next_array_index"
  done
}


window_selector() {
  # Check if zcurses module is loaded, if not attempt to load it
  if ! zmodload -e zsh/curses; then
    zmodload zsh/curses || { echo "Failed to load zcurses module"; exit 1; }
  fi

  local original_session="$1"
  local original_path=$(tmux display-message -p '#{pane_current_path}' -t "$original_session")

  local windows=$(tmux list-windows -t "$original_session" -F '#I:#W')
  local original_window=$(tmux display-message -t "$original_session" -p '#I')
  local window_array=()
  local window_indices=()
  local window_names=()
  local next_name=""

  reload_windows() {
    windows=$(tmux list-windows -t "$original_session" -F '#I:#W')
    original_window=$(tmux display-message -t "$original_session" -p '#I')
    window_array=()
    window_indices=()
    window_names=()

    # Parse windows into arrays
    for window in ${(f)windows}; do
      window_array+=("$window")
      window_indices+=($(echo "$window" | cut -d':' -f1))
      next_name=($(echo "$window" | cut -d':' -f2))
      window_names+="$next_name"
    done
  }

  reload_windows

  # Initialize zcurses
  zcurses init
  zcurses addwin main $LINES $COLUMNS 0 0
  zcurses bg main white/black
  zcurses clear main
  # zcurses cursor invisible

  # Menu state variables
  local current_pos=$(( original_window - 1 ))
  local start_pos=0
  local current_cut_pos=-1
  local max_visible=$(( LINES ))
  local key
  local selected_window=""

  update_preview() {
    local preview_window=${window_indices[current_pos+1]}
    tmux select-window -t "$original_session:$preview_window"
  }

  # Draw the menu
  draw_menu() {
    zcurses clear main
    zcurses move main 0 0
    local selected_row=1

    # Display visible window items
    local visible_end=$(( start_pos + max_visible ))
    [[ $visible_end -gt ${#window_array} ]] && visible_end=${#window_array}

    for ((i = start_pos; i < visible_end; i++)); do
      local row=$(( i - start_pos + 0 ))
      zcurses move main $row 0
      local text_length=${#window_indices[i+1]}

      if [[ $i -eq $current_pos ]]; then
        # Highlight current selection
        zcurses attr main 241/white
        zcurses string main " ${window_indices[i+1]}: "

        if [[ $i -eq $current_cut_pos ]]; then
          zcurses attr main magenta/white
        else
          zcurses attr main black/white
        fi
        zcurses string main "${window_names[i+1]} "

        # Calculate how many spaces needed to fill the rest of the line
        text_length=$(( text_length + 2 + ${#window_names[i+1]} ))  # +2 for ": "
        local padding_needed=$(( COLUMNS - text_length - 2 ))  # -2 for the left margin

        # Add padding spaces to fill the line with the highlight
        [[ $padding_needed -gt 0 ]] && zcurses string main "$(printf '%*s' $padding_needed '')"

        selected_row=$row

        # Reset attributes for next line
        zcurses attr main white/black
      else
        zcurses attr main 241/black
        zcurses string main " ${window_indices[i+1]}: "
        if [[ $i -eq $current_cut_pos ]]; then
          zcurses attr main magenta/black
        else
          zcurses attr main white/black
        fi
        zcurses string main "${window_names[i+1]}"
      fi
    done

    # zcurses move main $selected_row 0
    zcurses move main $selected_row $(( COLUMNS - 1 ))
    zcurses refresh main
  }

  # Main input loop
  while true; do
    draw_menu

    zcurses input main key

    case $key in
      1|2|3|4|5|6|7|8|9)
          current_pos=$(($key - 1))
          start_pos=0
          update_preview
          break
          ;;
      a)
          echo "tmux new-window -c \"$original_path\" -t \"$original_session\" -n \"new-window\" \
            \; command-prompt -p \" Name window:\" \"rename-window '%%'\"" \
            > "$TMP_COMMAND_FILE"
          break
          ;;
      j)
          ((current_pos < ${#window_array} - 1)) && ((current_pos++))
          # Scroll if needed
          if ((current_pos >= start_pos + max_visible)); then
            ((start_pos++))
          fi
          update_preview
          ;;
      k)
          ((current_pos > 0)) && ((current_pos--))
          # Scroll if needed
          if ((current_pos < start_pos)); then
            ((start_pos--))
          fi
          update_preview
          ;;
      d)
          echo "tmux confirm-before -p \" Kill window?\" kill-window" > "$TMP_COMMAND_FILE"
          break
          ;;
      r)
          echo "tmux command-prompt -p \" Rename window:\" \"rename-window '%%'\"" \
            > "$TMP_COMMAND_FILE"
          break
          ;;
      p|P)
          if [[ $current_cut_pos -ne -1 ]]; then
            if [[ "$current_cut_pos" -ne "current_pos" ]]; then
              local direction="up"
              if [[ "$key" -eq "p" ]]; then
                direction="down"
              fi
              move_window_index "$original_session" \
                "${window_indices[current_cut_pos+1]}" \
                "${window_indices[current_pos+1]}" \
                "$direction"

              if [[ $current_cut_pos -gt $current_pos && "$direction" == "down" ]]; then
                current_pos=$(( current_pos + 1 ))
              fi
            fi
            current_cut_pos=-1
            reload_windows
            update_preview
          fi
          ;;
      x)
          current_cut_pos=$current_pos
          ;;
      $'\e')  # Quit without selection
          current_pos=$(( original_window - 1 ))
          update_preview
          break
          ;;
      $'\n') # Enter key
          break
          ;;
    esac
  done

  # Clean up zcurses
  # zcurses cursor normal
  zcurses delwin main
  zcurses end
}


if [[ "$1" == "show-window-chooser" ]]; then
  current_session=$(tmux display-message -p '#S')

  num_windows=$(tmux list-windows -t "$current_session" | wc -l)

  num_characters=$(tmux list-windows -t "$current_session" -F '#{window_name}' | \
    awk '{ print length($0) }' | \
    sort -nr | \
    head -n 1)

  popup_height=$(( num_windows + 2 ))
  popup_width=$(( num_characters + 9 ))

  tmux display-popup -h "$popup_height" -w "$popup_width" \
    -T "#[align=centre fg=yellow] Windows " \
    -EE "$0 show-window-chooser-body '$current_session'"

  check_tmux_command_file
  exit $?
fi


if [[ "$1" == "show-window-chooser-body" ]]; then
  original_session="$2"
  window_selector "$original_session"
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
  session_count=$(tmux list-sessions 2>/dev/null | wc -l)
  window_count=$(tmux list-windows -a 2>/dev/null | wc -l)
  total_count=$((session_count + window_count))
  total_height=$((total_count + 7))

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

  total_width=$((longest_name + 4))

  tmux display-popup -h "$total_height" -w "$total_width" \
    -b rounded \
    -T "#[align=centre fg=white] supertree " \
    -EE "$0 show-supertree-body"

  check_tmux_command_file
fi


if [[ "$1" == "show-supertree-body" ]]; then

  if [ -d "${HOME}/github/jvs/tmux-supertree" ]; then
    cd "${HOME}/github/jvs/tmux-supertree"
  else
    SCRIPT_PATH="$0"
    if [ -L "$SCRIPT_PATH" ]; then
      REAL_PATH=$(readlink -f "$SCRIPT_PATH")
    else
      REAL_PATH="$SCRIPT_PATH"
    fi

    BIN_DIR=$(dirname "$REAL_PATH")

    cd "$BIN_DIR/../runtime/tmux-supertree"
  fi

  uv run python -m tmux_supertree.main \
    --command-file "$TMP_COMMAND_FILE" \
    --return-command "$0 show-supertree"
fi
