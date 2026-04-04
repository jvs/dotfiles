#!/usr/bin/env bash

MISE="$HOME/.local/bin/mise"
PI_HOME="$HOME/.local/tools/pi"

pi_node() {
  "$MISE" exec node@24 -- "$@"
}

# Create PI_HOME (if needed) and install pi into it.
pi_install() {
  mkdir -p "$PI_HOME"
  (cd "$PI_HOME" && pi_node npm init -y && pi_node npm install @mariozechner/pi-coding-agent)
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
