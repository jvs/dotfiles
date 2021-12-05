# If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:/usr/local/bin:/usr/bin:/bin:$PATH
export PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"


# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"
# NOTE:
# !! use custom/history.zsh

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh


# User configuration

export EDITOR='nvim'


if [[ `uname` == "Darwin" ]]; then
    # See: https://github.com/larkery/zsh-histdb#note-for-os-x-users
    HISTDB_TABULATE_CMD=(sed -e $'s/\x1f/\t/g')
fi

source $ZSH/custom/plugins/zsh-histdb/sqlite-history.zsh
autoload -Uz add-zsh-hook

source $ZSH/custom/plugins/zsh-histdb/histdb-interactive.zsh
bindkey '^f' _histdb-isearch


# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="vim ~/.zshrc"
# alias ohmyzsh="vim ~/.oh-my-zsh"

# Use G by itself to pipe to grep.
alias -g G='| grep -i'


# MOTD
function echo_color() {
    local color="$1"
    printf "${color}$2\033[0m\n"
}


function greet() {
    echo_color "\033[0;90m" "c-f  Move forward"
    echo_color "\033[0;90m" "c-b  Move backward"
    echo_color "\033[0;90m" "c-p  Move up"
    echo_color "\033[0;90m" "c-n  Move down"
    echo_color "\033[0;90m" "c-a  Jump to beginning of line"
    echo_color "\033[0;90m" "c-e  Jump to end of line"
    echo_color "\033[0;90m" "c-d  Delete forward"
    echo_color "\033[0;90m" "c-h  Delete backward"
    echo_color "\033[0;90m" "c-k  Delete forward to end of line"
    echo_color "\033[0;90m" "c-u  Delete entire line"
    echo_color "\033[0;90m" "c-f  Reverse search histdb"
    echo_color "\033[0;90m" "see: bindkey"
    echo_color "\033[0;90m" "also: histdb --help"
    echo_color "\033[0;90m" "... _histdb_query, local_hist, greet"
}

greet


# See: https://github.com/larkery/zsh-histdb#integration-with-zsh-autosuggestions
_zsh_autosuggest_strategy_histdb_top() {
    local query="
        select commands.argv from history
        left join commands on history.command_id = commands.rowid
        left join places on history.place_id = places.rowid
        where commands.argv LIKE '$(sql_escape $1)%'
        group by commands.argv, places.dir
        order by places.dir != '$(sql_escape $PWD)', count(*) desc
        limit 1
    "
    suggestion=$(_histdb_query "$query")
}

ZSH_AUTOSUGGEST_STRATEGY=histdb_top


local_hist() {
    limit="${1:-10}"
    local query="
        select history.start_time, commands.argv
        from history left join commands on history.command_id = commands.rowid
        left join places on history.place_id = places.rowid
        where places.dir LIKE '$(sql_escape $PWD)%'
        order by history.start_time desc
        limit $limit
    "
    results=$(_histdb_query "$query")
    echo "$results"
}


# will show 10 results:
# local_hist

# will show 50 results:
# local_hist 50


# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
