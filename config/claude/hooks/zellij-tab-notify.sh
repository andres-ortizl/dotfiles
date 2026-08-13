#!/bin/bash
# Claude Code <-> zellij tab notifier.
# "prompt" runs on UserPromptSubmit: the user is focused on this tab, so
# current-tab-info is authoritative. Store tab id + clean name, clear any mark.
# "alert" runs on Stop/Notification: mark the stored tab by id (works while
# the user is on another tab) and play a sound.

MODE="$1"
SOUND="/System/Library/Sounds/Funk.aiff"
MARK="❗ "

[ -n "$ZELLIJ_SESSION_NAME" ] && [ -n "$ZELLIJ_PANE_ID" ] || exit 0
STATE_DIR="$HOME/.claude/zellij-tab-state"
STATE_FILE="$STATE_DIR/${ZELLIJ_SESSION_NAME}-pane-${ZELLIJ_PANE_ID}"

case "$MODE" in
  prompt)
    mkdir -p "$STATE_DIR"
    info=$(zellij action current-tab-info 2>/dev/null) || exit 0
    id=$(printf '%s\n' "$info" | sed -n 's/^id: //p')
    name=$(printf '%s\n' "$info" | sed -n 's/^name: //p')
    clean=${name#"$MARK"}
    [ -n "$id" ] || exit 0
    printf '%s\t%s\n' "$id" "$clean" > "$STATE_FILE"
    if [ "$name" != "$clean" ]; then
      zellij action rename-tab --tab-id "$id" "$clean" 2>/dev/null
    fi
    ;;
  alert)
    [ -f "$STATE_FILE" ] || exit 0
    IFS=$'\t' read -r id clean < "$STATE_FILE"
    [ -n "$id" ] || exit 0
    zellij action rename-tab --tab-id "$id" "$MARK$clean" 2>/dev/null
    afplay "$SOUND" >/dev/null 2>&1 &
    ;;
esac
exit 0
