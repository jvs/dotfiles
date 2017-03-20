# Source bashrc if it hasn't been sourced yet.
DF_SOURCED_BASH_PROFILE=1
[ -n "$DF_SOURCED_BASHRC" ] && source ~/.bashrc


# Source all the other shell-related dotfiles.
for dotfile in ~/.{path,bash_prompt,exports,aliases,functions,extra}; do
    [ -r "$dotfile" ] && [ -f "$dotfile" ] && source "$dotfile"
done
unset dotfile
