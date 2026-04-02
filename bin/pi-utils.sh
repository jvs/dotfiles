#!/usr/bin/env bash

PI_HOME="$HOME/.local/tools/pi"

pi_node() {
  "$HOME/.local/bin/mise" exec node@24 -- "$@"
}

case "$1" in
  run)
    pi_node "$PI_HOME/node_modules/.bin/pi" "${@:2}"
    ;;
  update)
    (cd "$PI_HOME" && pi_node npm update)
    ;;
  setup)
    curl https://mise.run | sh
    mkdir -p "$PI_HOME"
    (cd "$PI_HOME" && pi_node npm init -y && pi_node npm install @mariozechner/pi-coding-agent)
    ;;
  *)
    echo "Usage: pi-utils {setup|update|run [args...]}"
    ;;
esac
