#!/usr/bin/env bash

set -uo pipefail

readonly runtime_dir="${XDG_RUNTIME_DIR:?}/pi-beacon"
readonly socket_path="$runtime_dir/api.sock"
readonly stream_command="$HOME/.local/bin/pi-beacon-stream"

stream_pid=""
watcher_pid=""
hidden_emitted=false

emit_hidden() {
  if [ "$hidden_emitted" = false ]; then
    jq -cn '{text:"", class:"inactive", tooltip:""}'
    hidden_emitted=true
  fi
}

start_stream() {
  if [ -n "$stream_pid" ] && kill -0 "$stream_pid" 2>/dev/null; then
    return
  fi

  "$stream_command" --format waybar &
  stream_pid=$!
  hidden_emitted=false
}

stop_stream() {
  if [ -n "$stream_pid" ] && kill -0 "$stream_pid" 2>/dev/null; then
    kill "$stream_pid" 2>/dev/null || true
    wait "$stream_pid" 2>/dev/null || true
  fi
  stream_pid=""
}

sync_state() {
  if [ -S "$socket_path" ] && systemctl --user is-active --quiet pi-beacon.service; then
    start_stream
  else
    stop_stream
    emit_hidden
  fi
}

# Invoked indirectly by the EXIT, INT, and TERM traps.
# shellcheck disable=SC2329
cleanup() {
  stop_stream
  if [ -n "$watcher_pid" ] && kill -0 "$watcher_pid" 2>/dev/null; then
    kill "$watcher_pid" 2>/dev/null || true
    wait "$watcher_pid" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

mkdir -p "$runtime_dir"
coproc SOCKET_EVENTS {
  exec inotifywait -m -q \
    -e create,delete,moved_to,moved_from,delete_self,move_self \
    --format '%e|%f' "$runtime_dir"
}
watcher_fd="${SOCKET_EVENTS[0]}"
watcher_pid="$SOCKET_EVENTS_PID"

sync_state
while IFS='|' read -r events file <&"$watcher_fd"; do
  if [ "$file" = "api.sock" ]; then
    sync_state
  elif [[ "$events" == *DELETE_SELF* || "$events" == *MOVE_SELF* ]]; then
    break
  fi
done

exit 1
