#!/usr/bin/env zsh
# git-addp: runs "git add -p" then prompts about each untracked file.
# Options per file: (a)dd, (s)kip, (i)gnore forever (appends to .gitignore)

set -e

git add -p

# Find untracked files not already excluded
untracked=(${(f)"$(git ls-files --others --exclude-standard)"})

if [[ ${#untracked[@]} -eq 0 ]]; then
  exit 0
fi

# Find the repo root for .git/info/exclude (local-only ignore)
repo_root=$(git rev-parse --show-toplevel)
gitignore="$repo_root/.git/info/exclude"

print ""
print "Untracked files:"

for file in $untracked; do
  while true; do
    print -n "  $file  [(a)dd / (s)kip / (i)gnore forever]? "
    read -r choice
    case $choice in
      a|A)
        git add -- "$file"
        print "  -> added"
        break
        ;;
      s|S|"")
        print "  -> skipped"
        break
        ;;
      i|I)
        # Make path relative to repo root for .gitignore
        rel=$(python3 -c "import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" "$file" "$repo_root")
        print "$rel" >> "$gitignore"
        print "  -> added '$rel' to .gitignore"
        break
        ;;
      *)
        print "  Please enter a, s, or i."
        ;;
    esac
  done
done
