#!/usr/bin/env bash
#
# Waybar notification module. Shows the latest desktop notification, or a mute
# icon when dunst is paused. Reads dunst's own history via `dunstctl history`
# (JSON) instead of sniffing D-Bus, so no separate collector service is needed.

set -u

default_timeout=8

emit() {
  jq -cn --arg text "$1" --arg alt "notification" --arg class "$2" \
    '{text:$text, alt:$alt, class:$class}'
}

last_state=""
last_id=""
shown_until=0

newest_notification() {
  dunstctl history 2>/dev/null | jq -r '
    .data[0][0]
    | select(. != null)
    | [.id.data, .summary.data // "", .appname.data // "", .body.data // ""]
    | @tsv
  '
}

is_paused() { [ "$(dunstctl is-paused 2>/dev/null || echo false)" = "true" ]; }

# Don't re-show whatever is already in history when the script starts.
if current="$(newest_notification)"; then
  last_id="${current%%$'\t'*}"
fi

while true; do
  if is_paused; then
    state="collapsed_muted"
    [ "$state" != "$last_state" ] && emit "󰂚" "$state"
    last_state="$state"
    sleep 0.9
    continue
  fi

  newest="$(newest_notification)"
  if [ -z "$newest" ]; then
    state="collapsed"
    [ "$state" != "$last_state" ] && emit "󰂚" "$state"
    last_state="$state"
    sleep 0.9
    continue
  fi

  IFS=$'\t' read -r id summary appname body <<<"$newest"

  if [ "$id" != "$last_id" ]; then
    last_id="$id"
    shown_until=$(( $(date +%s) + default_timeout ))
    if [ "$summary" = "swww" ] && [ "$body" = "1" ]; then
      state="wallpaper"
      emit "" "$state"
    else
      state="expanded"
      emit "${summary}: ${body}" "$state"
    fi
    last_state="$state"
  else
    if [ "$(date +%s)" -ge "$shown_until" ]; then
      state="collapsed"
      [ "$state" != "$last_state" ] && emit "󰂚" "$state"
      last_state="$state"
    fi
  fi

  sleep 0.5
done