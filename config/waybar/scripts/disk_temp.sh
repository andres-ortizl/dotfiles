#!/bin/bash

nvme0_temp=$(cat /sys/class/nvme/nvme0/hwmon*/temp1_input 2>/dev/null)
nvme1_temp=$(cat /sys/class/nvme/nvme1/hwmon*/temp1_input 2>/dev/null)
nvme1_sensor2=$(cat /sys/class/nvme/nvme1/hwmon*/temp3_input 2>/dev/null)

t0=$((nvme0_temp / 1000))
t1=$((nvme1_temp / 1000))
s2=$((nvme1_sensor2 / 1000))

if [ -n "$t0" ] && [ -n "$t1" ]; then
  text="󰋊 ${t1}°C / ${t0}°C"
  tooltip="Samsung 990 PRO: ${t1}°C (sensor2: ${s2}°C)\nCrucial P2: ${t0}°C"
  if [ "$s2" -ge 90 ]; then
    text="󰋊 ${t1}°C󱞩${s2}°C / ${t0}°C"
  fi
  echo "{\"text\": \"$text\", \"tooltip\": \"$tooltip\"}"
else
  echo "{\"text\": \"󰋊 N/A\", \"tooltip\": \"NVMe temps unavailable\"}"
fi
