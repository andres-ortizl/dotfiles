#!/usr/bin/env bash
#
# Waybar notification module. Shows the latest desktop notification, or a mute
# icon when Dunst is paused. D-Bus property changes trigger updates, so the
# module does not poll while the desktop is idle.

set -uo pipefail

readonly default_timeout=8
readonly dunst_service="org.freedesktop.Notifications"
readonly dunst_object="/org/freedesktop/Notifications"

last_state=""
last_id=""
collapse_at=0
monitor_pid=""

emit() {
  jq -cn --arg text "$1" --arg alt "notification" --arg class "$2" \
    '{text:$text, alt:$alt, class:$class}'
}

emit_collapsed() {
  local state="collapsed"

  if is_paused; then
    state="collapsed_muted"
  fi

  if [ "$state" != "$last_state" ]; then
    emit "󰂚" "$state"
    last_state="$state"
  fi
  collapse_at=0
}

newest_notification() {
  dunstctl history 2>/dev/null | jq -r '
    .data[0][0]
    | select(. != null)
    | [.id.data, .summary.data // "", .body.data // ""]
    | @tsv
  '
}

is_paused() {
  [ "$(dunstctl is-paused 2>/dev/null || echo false)" = "true" ]
}

refresh() {
  local newest id summary body state

  if is_paused; then
    emit_collapsed
    return
  fi

  newest="$(newest_notification)"
  if [ -z "$newest" ]; then
    last_id=""
    emit_collapsed
    return
  fi

  IFS=$'\t' read -r id summary body <<<"$newest"
  if [ "$id" = "$last_id" ]; then
    if [ "$last_state" = "collapsed_muted" ]; then
      emit_collapsed
    fi
    return
  fi

  last_id="$id"
  collapse_at=$((EPOCHSECONDS + default_timeout))
  if [ "$summary" = "swww" ] && [ "$body" = "1" ]; then
    state="wallpaper"
    emit "" "$state"
  else
    state="expanded"
    emit "${summary}: ${body}" "$state"
  fi
  last_state="$state"
}

# Invoked indirectly by the EXIT, INT, and TERM traps.
# shellcheck disable=SC2329
cleanup() {
  if [ -n "$monitor_pid" ] && kill -0 "$monitor_pid" 2>/dev/null; then
    kill "$monitor_pid" 2>/dev/null || true
    wait "$monitor_pid" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

# Do not re-show the newest historical notification when Waybar starts.
if current="$(newest_notification)"; then
  last_id="${current%%$'\t'*}"
fi
emit_collapsed

coproc DUNST_EVENTS {
  exec gdbus monitor --session --dest "$dunst_service" --object-path "$dunst_object"
}
monitor_fd="${DUNST_EVENTS[0]}"
monitor_pid="$DUNST_EVENTS_PID"

while true; do
  line=""
  if ((collapse_at > 0)); then
    remaining=$((collapse_at - EPOCHSECONDS))
    if ((remaining <= 0)); then
      emit_collapsed
      continue
    fi

    if ! IFS= read -r -t "$remaining" line <&"$monitor_fd"; then
      if kill -0 "$monitor_pid" 2>/dev/null; then
        emit_collapsed
        continue
      fi
      break
    fi
  elif ! IFS= read -r line <&"$monitor_fd"; then
    break
  fi

  case "$line" in
    *PropertiesChanged*)
      # One Dunst action can emit several adjacent property changes. Drain them
      # before refreshing to avoid duplicate D-Bus queries.
      while IFS= read -r -t 0.05 line <&"$monitor_fd"; do
        :
      done
      refresh
      ;;
  esac
done

exit 1
