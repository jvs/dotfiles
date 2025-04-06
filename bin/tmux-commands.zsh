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
  discard_window_index=-1
  if [ "$floating_session_exists" -eq 0 ]; then
    tmux new-session -d -s "$floating_session"

    discard_window_index=$(tmux display-message -p '#I')
  fi

  # Link the terminal window to the floating session.
  tmux link-window -s "$current_session:$terminal_window_index" -t "$floating_session"

  if [[ discard_window_index -ne -1 ]]; then
    tmux kill-window -t "$floating_session:$discard_window_index"
  fi

  tmux display-popup -h $popup_height -w $popup_width \
    -T "#[align=right fg=yellow] Terminal $terminal_window_suffix " \
    -EE "tmux attach-session -t $floating_session:$terminal_window_name"
  exit 0
fi


check_tmux_command_file() {
  if [[ -f /tmp/tmux_command_to_run ]]; then
    cmd=$(cat /tmp/tmux_command_to_run)
    rm -rf /tmp/tmux_command_to_run
    eval "tmux $cmd"
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
    ["Create New Session"]="command-prompt -p \"New Session:\" \"new-session -A -s '%%'\""
    ["Choose Session"]="run-shell '$0 choose-session'"
    ["Kill Other Session"]="run-shell '$0 kill-session'"
    ["Rename Session"]="command-prompt -p \"Rename session:\" \"rename-session '%%'\""
    ["Switch to Last Session"]="switch-client -l"

    # Windows.
    ["Switch Windows"]="run-shell '$0 show-window-chooser'"

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
    ["Show World Time"]="display-popup -h 10 -w 29 \
      -T '#[align=centre fg=green] World Time ' \
      -E '$0 show-world-time && read -n 1'"

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
    echo ""
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

  if [[ "$source_array_index" -gt "$target_array_index" && direction == "down" ]]; then
    target_array_index=$(( target_array_index + 1 ))
  fi

  if [[ "$source_array_index" -lt "$target_array_index" && direction == "up" ]]; then
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
          echo "confirm-before -p \"Kill window?\" kill-window" > /tmp/tmux_command_to_run
          break
          ;;
      r)
          echo "command-prompt -p \"Rename window:\" \"rename-window '%%'\"" > /tmp/tmux_command_to_run
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

              if [[ $current_cut_pos -gt $current_pos && dirction == "down" ]]; then
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
