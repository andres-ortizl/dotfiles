#!/usr/bin/env bash
set -euo pipefail

sink_name=${1:-}
discord_sink="alsa_output.usb-Kingston_HyperX_Cloud_Flight_Wireless_Headset-00.analog-stereo"

sink_exists() {
    pactl list short sinks | awk -v target="$1" '$2 == target { found = 1 } END { exit !found }'
}

if [[ -z $sink_name ]]; then
    printf 'Usage: %s SINK_NAME\n' "$0" >&2
    exit 2
fi

if ! sink_exists "$sink_name"; then
    printf 'Unknown audio sink: %s\n' "$sink_name" >&2
    exit 1
fi

pactl set-default-sink "$sink_name"

while IFS=$'\t' read -r input_id application_binary application_name; do
    [[ -n $input_id ]] || continue
    target_sink=$sink_name

    if [[ ${application_binary,,} == discord* || ${application_name,,} == discord* ]]; then
        if sink_exists "$discord_sink"; then
            target_sink=$discord_sink
        else
            continue
        fi
    fi

    pactl move-sink-input "$input_id" "$target_sink" || true
done < <(
    pactl -f json list sink-inputs |
        jq -r '.[] | [.index, (.properties["application.process.binary"] // ""), (.properties["application.name"] // "")] | @tsv'
)
