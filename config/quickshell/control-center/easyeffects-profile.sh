#!/usr/bin/env bash

set -euo pipefail

readonly balanced_preset="HyperX Cloud Flight - AutoEQ"
readonly rap_preset="HyperX Cloud Flight - Rap"

last_loaded_preset() {
    easyeffects --hide-window --last-loaded-preset output 2>/dev/null || true
}

is_active() {
    pgrep -x easyeffects >/dev/null || return 1

    local bypass_state
    local loaded_preset
    bypass_state=$(easyeffects --hide-window --bypass 3 2>/dev/null || true)
    loaded_preset=$(last_loaded_preset)

    [[ $bypass_state == "2" && $loaded_preset == "$rap_preset" ]]
}

ensure_running() {
    if pgrep -x easyeffects >/dev/null; then
        return
    fi

    setsid -f easyeffects --service-mode </dev/null >/dev/null 2>&1

    for _ in {1..50}; do
        if pgrep -x easyeffects >/dev/null; then
            sleep 0.2
            return
        fi
        sleep 0.1
    done

    printf 'EasyEffects did not start\n' >&2
    return 1
}

show_status() {
    if is_active; then
        printf 'on\n'
    else
        printf 'off\n'
    fi
}

enable_profile() {
    ensure_running
    easyeffects --hide-window --load-preset "$rap_preset"
    easyeffects --hide-window --bypass 2
    printf 'on\n'
}

disable_profile() {
    ensure_running
    easyeffects --hide-window --load-preset "$balanced_preset"
    easyeffects --hide-window --bypass 2
    printf 'off\n'
}

suspend_profile() {
    if pgrep -x easyeffects >/dev/null; then
        easyeffects --hide-window --bypass 1
    fi
    printf 'off\n'
}

resume_profile() {
    ensure_running

    local loaded_preset
    loaded_preset=$(last_loaded_preset)
    if [[ $loaded_preset != "$balanced_preset" && $loaded_preset != "$rap_preset" ]]; then
        easyeffects --hide-window --load-preset "$balanced_preset"
    fi
    easyeffects --hide-window --bypass 2
    show_status
}

case ${1:-status} in
    status)
        show_status
        ;;
    on)
        enable_profile
        ;;
    off)
        disable_profile
        ;;
    suspend)
        suspend_profile
        ;;
    resume)
        resume_profile
        ;;
    toggle)
        if is_active; then
            disable_profile
        else
            enable_profile
        fi
        ;;
    *)
        printf 'Usage: %s {status|on|off|toggle|suspend|resume}\n' "$0" >&2
        exit 2
        ;;
esac
