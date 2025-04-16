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


TMP_COMMAND_FILE="/tmp/tmux_command_to_run"


if [[ "$1" == "show-menu" ]]; then
  tmux display-menu -T "#[align=centre fg=green] tmux " -x C -y C \
    "Open Supertree"              u "run-shell '$0 show-supertree'" \
    "Create New Session"          s "command-prompt -p \" New Session:\" \"new-session -A -s '%%'\"" \
    "Choose Session"              p "run-shell '$0 choose-session'" \
    "Choose Window"               t "choose-tree -wZ" \
    "Switch to Last Session"      h "switch-client -l" \
    "Rename Session"              n "command-prompt -p \" Rename session:\" \"rename-session '%%'\"" \
    "Kill Other Session"          q "run-shell '$0 kill-session'" \
    "" \
    "Create New Window"           w "new-window -c \"#{pane_current_path}\"" \
    "Choose Window in Session"    c "choose-tree -wf\"##{==:##{session_name},#{session_name}}\"" \
    "Open Window Menu"            o "run-shell '$0 show-window-menu'" \
    "Switch to Last Window"       l "last-window" \
    "Toggle Floating Terminal"    g "run-shell '$0 floating-terminal'" \
    "Rename Window"               r "command-prompt -p \" Rename window:\" \"rename-window '%%'\"" \
    "Kill Current Window"         e "confirm-before -p \" Kill window?\" kill-window" \
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
  floating_session_name="__floating_terminals__"
  floating_window_suffix=${2:-"J"}
  current_session_name=$(tmux display-message -p '#{session_name}')

  # If the floating terminal is already open, close it.
  if [[ "$current_session_name" = "$floating_session_name" ]]; then
    current_window_name=$(tmux display-message -p '#W')
    current_window_suffix=$(echo "$current_window_name" | cut -d'-' -f2)

    if [[ "$current_window_suffix" == "$floating_window_suffix" ]]; then
      tmux detach-client -s "$floating_session_name"
      exit 0
    fi
  fi

  current_path=$(tmux display-message -p '#{pane_current_path}')

  if [[ "$current_session_name" = "$floating_session_name" ]]; then
    # If a different floating terminal is open, get its source window ID.
    current_window_name=$(tmux display-message -p '#W')
    clean_window_id=$(echo "$current_window_name" | cut -d'-' -f3)
  else
    current_window_id=$(tmux display-message -p '#{window_id}')
    clean_window_id=${current_window_id//[^a-zA-Z0-9_\-]/}
  fi

  floating_window_name="terminal-$floating_window_suffix-$clean_window_id"

  floating_session_exists=$(tmux list-sessions -F '#{session_name}' \
    | grep -c "^$floating_session_name$")

  # Create the floating terminal session if it doesn't exist.
  # discard_window_id=''
  if [[ "$floating_session_exists" -eq 0 ]]; then
    tmux new-session -d -s "$floating_session_name"

    # discard_window_id=$(tmux display-message -t "$floating_session_name" -p '#{window_id}')
  fi

  # Check the floating session for the floating terminal window.
  floating_window_exists=$(tmux list-windows \
    -t "$floating_session_name" \
    -F '#{window_name}' \
    | grep -c "^${floating_window_name}$")

  # Create the floating window if it doesn't exist.
  if [[ "$floating_window_exists" -eq 0 ]]; then
    tmux new-window -d \
      -t "$floating_session_name" \
      -n "$floating_window_name" \
      -c "$current_path"
  fi

  # Get the ID of the floating window.
  floating_window_id=$(tmux list-windows \
    -t "$floating_session_name" \
    -F '#{window_id}:#{window_name}' \
    | grep ":${floating_window_name}$" | cut -d':' -f1)

  if [[ ! "$floating_window_id" ]]; then
    echo "Error: Terminal window not found."
    exit 0
  fi

  # if [[ discard_window_id != '' ]]; then
  #   tmux kill-window -t "$floating_session_name:$discard_window_id"
  # fi

  if [[ "$current_session_name" = "$floating_session_name" ]]; then
    tmux detach-client -s "$floating_session_name"
  fi

  popup_height="80%"
  popup_width="80%"

  # Save the original terminal size
  original_height=$(tmux display-message -p '#{client_height}')
  original_width=$(tmux display-message -p '#{client_width}')

  # Calculate the popup size in characters
  popup_height_chars=$(( $original_height * 80 / 100 ))
  popup_width_chars=$(( $original_width * 80 / 100 ))

  tmux resize-window -t "$floating_window_id" -x $popup_width_chars -y $popup_height_chars

  tmux display-popup -h $popup_height -w $popup_width \
    -T "#[align=right fg=yellow] Terminal $floating_window_suffix " \
    -EE "tmux attach-session -t '$floating_session_name:$floating_window_id'"

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

    # Windows.
    ["Switch Windows"]="run-shell '$0 show-window-chooser'"

    # ["Choose Window in Current Session"]="choose-tree -wf\"##{==:##{session_name},#{session_name}}\""
    ["Choose Window"]="choose-tree -wZ"
    ["Create New Window"]="new-window -c \"#{pane_current_path}\""
    ["Maximize Window"]="resize-window -A"
    ["Open Window Menu"]="run-shell '$0 show-window-menu'"
    ["Kill Current Window"]="confirm-before -p \" Kill window?\" kill-window"
    ["Rename Window"]="command-prompt -p \" Rename window:\" \"rename-window '%%'\""
    ["Switch to Last Window"]="last-window"

    # Panes.
    ["Kill Current Pane"]="confirm-before -p \" Kill pane?\" kill-pane"
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
    ["Show Command Prompt"]="command-prompt -p ' Command:'"
    ["Show Messages"]="show-messages"
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
  logest_window_name=$((longest_window_name + 3))

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
  SCRIPT_PATH="$0"
  if [ -L "$SCRIPT_PATH" ]; then
    REAL_PATH=$(readlink -f "$SCRIPT_PATH")
  else
    REAL_PATH="$SCRIPT_PATH"
  fi

  BIN_DIR=$(dirname "$REAL_PATH")

  cd "$BIN_DIR/../runtime/tmux-supertree"
  uv run python -m tmux_supertree.main \
    --command-file "$TMP_COMMAND_FILE" \
    --return-command "$0 show-supertree"
fi
