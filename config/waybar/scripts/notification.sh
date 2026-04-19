#!/bin/bash

default_timeout=3
store_dir="$HOME/.config/waybar/store"
notif_file="$store_dir/lastnotif"
lockdir="$store_dir/getnotification.lock"

mkdir -p "$store_dir"

# Start metadata collector if it's not already running.
if ! pgrep -f "getnotification.sh$" >/dev/null && [ ! -d "$lockdir" ]; then
  "$HOME/.config/waybar/scripts/getnotification.sh" >/dev/null 2>&1 &
  sleep 0.2
fi

emit() {
  local text="$1"
  local cls="$2"
  jq -cn --arg text "$text" --arg alt "notification" --arg class "$cls" \
    '{text:$text, alt:$alt, class:$class}'
}

last_state=""
shown_timestamp=""

while true; do
  dunst_paused="$(dunstctl is-paused 2>/dev/null || echo false)"
  realtime="$(date +%s)"

  timestamp=0
  summary=""
  body=""

  if [ -f "$notif_file" ]; then
    while IFS=': ' read -r key value; do
      case "$key" in
        timestamp) timestamp="${value:-0}" ;;
        summary) summary="$value" ;;
        body) body="$value" ;;
      esac
    done <"$notif_file"
  fi

  timediff=$((realtime - timestamp))

  if [ "$dunst_paused" = "true" ]; then
    state="collapsed_muted"
    [ "$state" != "$last_state" ] && emit "󰂚" "$state"
    last_state="$state"
    sleep 0.9
    continue
  fi

  if [ "$timediff" -gt $((default_timeout - 1)) ]; then
    state="collapsed"
    [ "$state" != "$last_state" ] && emit "󰂚" "$state"
    last_state="$state"
    sleep 0.9
    continue
  fi

  if [ "$timestamp" = "$shown_timestamp" ]; then
    sleep 0.4
    continue
  fi

  if [ "$summary" = "swww" ] && [ "$body" = "1" ]; then
    emit "" "wallpaper"
    shown_timestamp="$timestamp"
    last_state="wallpaper"
    sleep 0.7
    continue
  fi

  emit "󰂚" "waiting_start"
  sleep 0.2
  emit "$summary: $body" "expanded"
  sleep "$default_timeout"
  emit "󰂚" "waiting_done"
  sleep 0.25
  shown_timestamp="$timestamp"
  last_state="waiting_done"
done
