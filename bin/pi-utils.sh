#!/usr/bin/env bash

MISE="$HOME/.local/bin/mise"
PI_HOME="$HOME/.local/tools/pi"

pi_node() {
  "$MISE" exec node@24 -- "$@"
}

# Resolve the current package name from the pi.dev API.
# Falls back to the known package name if the API is unreachable.
pi_package_name() {
  local api_name
  api_name=$(curl -sf --max-time 10 https://pi.dev/api/latest-version \
    | pi_node node -e "process.stdin.resume();let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{const j=JSON.parse(d);process.stdout.write(j.packageName||'')}catch{}})" \
    2>/dev/null)
  if [[ -n "$api_name" ]]; then
    echo "$api_name"
  else
    echo "@earendil-works/pi-coding-agent"
  fi
}

# Create PI_HOME (if needed) and install pi into it.
pi_install() {
  local pkg
  pkg=$(pi_package_name)
  echo "Installing $pkg ..."
  mkdir -p "$PI_HOME"
  (cd "$PI_HOME" && pi_node npm init -y && pi_node npm install "$pkg")
}

# Rotate backups: keep only the two most recent.
pi_rotate_backups() {
  # Drop the oldest slot before shifting down.
  rm -rf "${PI_HOME}.bak.2"
  [[ -d "${PI_HOME}.bak.1" ]] && mv "${PI_HOME}.bak.1" "${PI_HOME}.bak.2"
  mv "$PI_HOME" "${PI_HOME}.bak.1"
}

pi_restore() {
  if [[ ! -d "${PI_HOME}.bak.1" ]]; then
    echo "No backup found to restore."
    exit 1
  fi
  rm -rf "$PI_HOME"
  mv "${PI_HOME}.bak.1" "$PI_HOME"
  # Shift the older backup into the .bak.1 slot.
  [[ -d "${PI_HOME}.bak.2" ]] && mv "${PI_HOME}.bak.2" "${PI_HOME}.bak.1"
}

case "$1" in
  run)
    pi_node "$PI_HOME/node_modules/.bin/pi" "${@:2}"
    ;;
  update|upgrade)
    pi_rotate_backups
    pi_install
    ;;
  setup)
    if ! command -v mise &>/dev/null && [[ ! -x "$MISE" ]]; then
      curl https://mise.run | sh
    fi
    pi_install
    ;;
  restore)
    pi_restore
    ;;
  *)
    echo "Usage: pi-utils {setup|update|upgrade|restore|run [args...]}"
    ;;
esac
