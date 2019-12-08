#!/usr/bin/env bash

# Unstaged (*) and staged (+) changes will be shown next to the branch.
# https://github.com/git/git/blob/master/contrib/completion/git-prompt.sh
export GIT_PS1_SHOWDIRTYSTATE=1

# Make Python use UTF-8 encoding for output to stdin, stdout, and stderr.
export PYTHONIOENCODING='UTF-8';

# Prefer US English and use UTF-8.
export LANG='en_US.UTF-8';
export LC_ALL='en_US.UTF-8';

# Don’t clear the screen after quitting a manual page.
export MANPAGER='less -X';


# == Bash History Configuration ==
# The `.bash_prompt` keeps a `.complete_annotated_history` directory with a
# complete history of all our commands. So some of these settings are a bit
# redundant. (But bash history is just so useful!)

# Don't allow duplicate entries in the history.
export HISTCONTROL=ignoredups:erasedups

# Don't set any limits on the size of the history file.
export HISTFILESIZE=-1

# Allow upto 100,000 commands in memory. (Use -1 to just load everything.)
export HISTSIZE=100000

# Append to history instead of overwriting it.
shopt -s histappend

# Attempt to save all lines of a multiple-line command in the same history entry.
shopt -s cmdhist

# Save multi-line commands to the history with embedded newlines.
shopt -s lithist

# Resources:
# http://jesrui.sdf-eu.org/remember-all-your-bash-history-forever.html
# http://stackoverflow.com/questions/9457233/unlimited-bash-history
# http://unix.stackexchange.com/questions/1288/preserve-bash-history-in-multiple-terminal-windows


# == Bash Prompt Configuration ==
# Stores the initial user.
JVS_INITIAL_USER=$USER

# Records `$?` (in case someone runs another command).
JVS_EXIT_STATUS=0

# Indicates if we're waiting for the user's very first command.
JVS_IS_FIRST=1

# Records the user's previous working directory.
JVS_PREV_WD=$HOME

# Stores the location of the user's complete annotated history.
JVS_HISTORY_DIR=$HOME/.complete_annotated_bash_history


if [ -f ~/git-prompt.sh ]; then
    source ~/git-prompt.sh
fi


jvs_abbreviate_dir() {
    if [ $1 = /Users/$JVS_INITIAL_USER ]; then
        echo '~'
    elif [[ $1 = /Users/$JVS_INITIAL_USER* ]]; then
        echo "~${1:${#JVS_INITIAL_USER} + 7}"
    else
        echo $1
    fi
}

jvs_abbreviate_user() {
    if [ $1 = $JVS_INITIAL_USER ]; then
        echo 'self'
    else
        echo $USER
    fi
}

jvs_todays_history_file() {
    # Create a separate file for each day.
    echo $JVS_HISTORY_DIR/bash_history-`date +%Y%m%d`
}

jvs_record_history() {
    # Immediately append to the history file.
    history -a

    # Based on PROMPT_COMMAND by Michael Barrett:
    # http://signal0.com/2012/07/19/keeping_bash_history_forever.html

    [ -d $JVS_HISTORY_DIR ] || mkdir -p $JVS_HISTORY_DIR

    # Let's separate entries by a newline. I find it easier on the old eyes.
    echo >> `jvs_todays_history_file`

    # Write the shell's process id, the command's exit code, the current user,
    # and the previous working directory.
    echo "#pid=$$" \
        exit=$JVS_EXIT_STATUS \
        user=`jvs_abbreviate_user $USER` \
        pwd=`jvs_abbreviate_dir $JVS_PREV_WD`\
        >> `jvs_todays_history_file`

    # Write the day and time between ":" and ";" so that bash ignores them.
    # (This way you can copy and paste the line into the shell.) Also, add two
    # spaces between the time and the command. Seems a bit easier on the eyes.
    echo :`date +"%a %b %d %I:%M %p (%Y)"`\;\ \
        `history 1 | sed -E 's/^([0-9]*)[[:space:]]+/\1  /g'` \
        >> `jvs_todays_history_file`

    # Record the working directory so that we can use it in the next entry.
    JVS_PREV_WD=$PWD
}

jvs_print_status() {
    local red='\e[0;31m'
    local yellow='\e[0;33m'
    local green='\e[32m'
    local cyan='\e[0;36m'
    local purple='\e[0;35m'
    local gray='\e[90m'

    if [ "$JVS_EXIT_STATUS" -eq 0 ]; then
        local usercolor=$green
        local dircolor=$cyan
        local branchcolor=$yellow
    else
        local usercolor='\e[1;31m'
        local dircolor=$red
        local branchcolor=$purple
    fi

    printf "\n$usercolor%s %s$dircolor %s$branchcolor$(__git_ps1 " [%s]")\n$gray" \
        `echo -n $(date +"%I:%M %p")` \
        `jvs_abbreviate_dir $PWD`
}

jvs_record_history_and_print_status() {
    # Define a global variable for "$?" so that both functions can use it.
    JVS_EXIT_STATUS="$?"

    # Don't record the annotated history when the shell first starts.
    if [ $JVS_IS_FIRST -ne 0 ]; then
        JVS_IS_FIRST=0
    else
        jvs_record_history
    fi
    jvs_print_status
}


# A handy function for searching the complete annotated history.
hsearch() {
    # Ignore lines that start with "#pid=". Also, color the timestamps gray.
    # (Use "\x5c" to print the slash character before the "1".)
    grep --no-filename "$@" $JVS_HISTORY_DIR/* \
        | grep -v "#pid=" \
        | sed "s/^\(:[^;]*;\)/`printf "\e[90m\x5c1\e[0m"`"/
}


PROMPT_COMMAND=jvs_record_history_and_print_status
PS1='`jvs_abbreviate_user $USER`> \[\e[0m\]'
