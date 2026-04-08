#!/usr/bin/env zsh
# git-addp: runs "git add -p" then prompts about each untracked file.
# Per-file options: y=stage  n=skip  q=quit  e=edit  p=pager  x=local-exclude  g=gitignore  ?=help

set -e

git add -p

# Collect untracked files not already excluded
untracked=(${(f)"$(git ls-files --others --exclude-standard)"})
[[ ${#untracked[@]} -eq 0 ]] && exit 0

repo_root=$(git rev-parse --show-toplevel)
total=${#untracked[@]}

# ── Colors (only when stdout is a terminal) ──────────────────────────────────
if [[ -t 1 ]]; then
  bold=$'\e[1m'
  cyan=$'\e[36m'
  green=$'\e[32m'
  yellow=$'\e[33m'
  dim=$'\e[2m'
  reset=$'\e[0m'
else
  bold='' cyan='' green='' yellow='' dim='' reset=''
fi

# ── Helpers ───────────────────────────────────────────────────────────────────

_is_binary() {
  if command -v file &>/dev/null; then
    local mime
    mime=$(file -b --mime-type "$1" 2>/dev/null)
    [[ $mime != text/* ]]
  else
    # Fallback: null bytes → binary
    LC_ALL=C grep -q $'\x00' "$1" 2>/dev/null
  fi
}

_format_size() {
  local bytes=$1
  if   (( bytes < 1024 ));    then print "${bytes} B"
  elif (( bytes < 1048576 )); then print "$(( bytes / 1024 )) KB"
  else                             print "$(( bytes / 1048576 )) MB"
  fi
}

_preview() {
  local file=$1

  if _is_binary "$file"; then
    local mime size_bytes size_fmt
    mime=$(file -b --mime-type "$file" 2>/dev/null || print "binary")
    size_bytes=$(wc -c < "$file" | awk '{print $1}')
    size_fmt=$(_format_size "$size_bytes")
    print "  ${dim}[binary — ${mime}, ${size_fmt}]${reset}"
    return
  fi

  local i=0 line total_lines
  total_lines=$(wc -l < "$file" | awk '{print $1}')
  while IFS= read -r line; do
    (( i++ ))
    # Truncate long lines
    if (( ${#line} > 200 )); then
      line="${line[1,200]}${reset}${dim}…"
    fi
    print "  ${dim}${line}${reset}"
    (( i >= 10 )) && break
  done < "$file"
  (( total_lines > i )) && print "  ${dim}… $(( total_lines - i )) more line(s)${reset}"
}

_to_repo_relative() {
  python3 -c "import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" "$1" "$repo_root"
}

_help() {
  print "  y - stage this file"
  print "  n - do not stage this file"
  print "  q - quit; do not stage this file or any remaining ones"
  print "  e - manually edit the current file"
  print "  p - view the full file in a pager"
  print "  x - exclude locally (.git/info/exclude, not committed)"
  print "  g - add to .gitignore (committed)"
  print "  ? - print help"
}

# ── Main loop ─────────────────────────────────────────────────────────────────
print ""

index=0
for file in "${untracked[@]}"; do
  (( index++ ))

  # Header: counter + filename
  print "${bold}($index/$total) ${cyan}${file}${reset}"
  _preview "$file"
  print ""

  while true; do
    print -n "Stage this file? ${bold}[${cyan}y,n,q,e,p,x,g,?${reset}${bold}]${reset} "
    read -r -k 1 choice
    print ""

    case $choice in
      y|Y)
        git add -- "$file"
        print "${green}staged${reset}"
        break
        ;;
      n|N|$'\n')
        print "skipped"
        break
        ;;
      q|Q)
        print "quit"
        exit 0
        ;;
      e|E)
        ${VISUAL:-${EDITOR:-vi}} "$file"
        ;;
      p|P)
        ${PAGER:-less} -FX "$file"
        ;;
      x|X)
        rel=$(_to_repo_relative "$file")
        print "$rel" >> "$repo_root/.git/info/exclude"
        print "${yellow}excluded${reset} — added '${rel}' to .git/info/exclude"
        break
        ;;
      g|G)
        rel=$(_to_repo_relative "$file")
        print "$rel" >> "$repo_root/.gitignore"
        print "${yellow}ignored${reset} — added '${rel}' to .gitignore"
        break
        ;;
      \?)
        _help
        ;;
      *)
        print "unknown command '${choice}' — press ? for help"
        ;;
    esac
  done

  print ""
done
