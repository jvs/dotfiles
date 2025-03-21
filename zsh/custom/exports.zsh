# Don't clear the screen after quitting a manual page.
export MANPAGER='less -X';

# Make Python use UTF-8 encoding for output to stdin, stdout, and stderr.
export PYTHONIOENCODING='UTF-8';

# Prefer US English and use UTF-8.
export LANG='en_US.UTF-8';
export LC_ALL='en_US.UTF-8';

# Some git aliases.
alias branches='git branch --sort=-committerdate'
alias co='branches | fzf --height=50% --reverse --info=inline | xargs git checkout'
alias delbr="git branch --no-color --sort=-committerdate | fzf -m --reverse | xargs -I {} git branch -D '{}'"
alias gcp='git cherry-pick -x'
alias glog='git log --pretty=format:"%h%x09%an%x09%ad%x09%s"'
# alias glog='git log --graph --pretty=format:"%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset" --abbrev-commit'
