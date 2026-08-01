#!/usr/bin/env bash

export LC_ALL=C

read_cpu() {
  read -r _ user nice system idle iowait irq softirq steal _ </proc/stat
  cpu_idle=$((idle + iowait))
  cpu_total=$((user + nice + system + idle + iowait + irq + softirq + steal))
}

read_cpu
first_idle=$cpu_idle
first_total=$cpu_total
sleep 0.2
read_cpu

total_delta=$((cpu_total - first_total))
idle_delta=$((cpu_idle - first_idle))
cpu_usage=$((100 * (total_delta - idle_delta) / total_delta))

read -r memory_total memory_used < <(free -b | awk '/^Mem:/ { print $2, $3 }')
memory_percent=$((100 * memory_used / memory_total))
memory_used_gib=$(awk -v value="$memory_used" 'BEGIN { printf "%.1f", value / 1073741824 }')
memory_total_gib=$(awk -v value="$memory_total" 'BEGIN { printf "%.1f", value / 1073741824 }')

cpu_temp=0
for name_file in /sys/class/hwmon/hwmon*/name; do
  read -r sensor_name <"$name_file"
  if [[ "$sensor_name" == "k10temp" ]]; then
    read -r raw_temp <"${name_file%/name}/temp1_input"
    cpu_temp=$((raw_temp / 1000))
    break
  fi
done

gpu_temp=0
gpu_usage=0
gpu_memory_used=0
gpu_memory_total=0
gpu_model="GPU"
if command -v nvidia-smi >/dev/null 2>&1; then
  IFS=',' read -r gpu_model gpu_temp gpu_usage gpu_memory_used gpu_memory_total < <(
    nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits
  )
  gpu_model=$(xargs <<<"$gpu_model")
  gpu_temp=${gpu_temp// /}
  gpu_usage=${gpu_usage// /}
  gpu_memory_used=${gpu_memory_used// /}
  gpu_memory_total=${gpu_memory_total// /}
fi

cpu_model=$(awk -F: '/model name/ { value=$2; sub(/^[[:space:]]+/, "", value); print value; exit }' /proc/cpuinfo)
cpu_model=$(sed -E 's/^AMD //; s/ [0-9]+-Core Processor$//' <<<"$cpu_model")
board_model="Mainboard"
if [[ -r /sys/class/dmi/id/board_name ]]; then
  read -r board_model </sys/class/dmi/id/board_name
fi

nvme0_temp=0
nvme1_temp=0
for temp_file in /sys/class/nvme/nvme*/hwmon*/temp1_input; do
  read -r raw_temp <"$temp_file"
  case "$temp_file" in
    */nvme0/*) nvme0_temp=$((raw_temp / 1000)) ;;
    */nvme1/*) nvme1_temp=$((raw_temp / 1000)) ;;
  esac
done

nvme0_model="NVMe 0"
nvme1_model="NVMe 1"
[[ -r /sys/class/nvme/nvme0/model ]] && read -r nvme0_model </sys/class/nvme/nvme0/model
[[ -r /sys/class/nvme/nvme1/model ]] && read -r nvme1_model </sys/class/nvme/nvme1/model

pump_rpm=0
aio_fan_rpm=0
board_fan2_rpm=0
board_fan7_rpm=0
coolant_temp=0
if command -v sensors >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  sensor_json=$(sensors -j 2>/dev/null)
  read -r pump_rpm aio_fan_rpm board_fan2_rpm board_fan7_rpm coolant_temp < <(
    jq -r '
      def device(prefix): [to_entries[] | select(.key | startswith(prefix))][0].value;
      (device("kraken2023") // {}) as $kraken |
      (device("nct6799") // {}) as $board |
      [
        ($kraken."Pump speed".fan1_input // 0),
        ($kraken."Fan speed".fan2_input // 0),
        ($board.fan2.fan2_input // 0),
        ($board.fan7.fan7_input // 0),
        ($kraken."Coolant temp".temp1_input // 0)
      ] | @tsv
    ' <<<"$sensor_json"
  )
  pump_rpm=${pump_rpm%.*}
  aio_fan_rpm=${aio_fan_rpm%.*}
  board_fan2_rpm=${board_fan2_rpm%.*}
  board_fan7_rpm=${board_fan7_rpm%.*}
fi

jq -cn \
  --arg cpuModel "$cpu_model" \
  --arg gpuModel "$gpu_model" \
  --arg boardModel "$board_model" \
  --arg nvme0Model "$nvme0_model" \
  --arg nvme1Model "$nvme1_model" \
  --arg pumpModel "NZXT Kraken 2023" \
  --arg memoryUsed "$memory_used_gib" \
  --arg memoryTotal "$memory_total_gib" \
  --argjson cpu "$cpu_usage" \
  --argjson cpuTemp "$cpu_temp" \
  --argjson memoryPercent "$memory_percent" \
  --argjson gpu "$gpu_usage" \
  --argjson gpuTemp "$gpu_temp" \
  --argjson gpuMemoryUsed "$gpu_memory_used" \
  --argjson gpuMemoryTotal "$gpu_memory_total" \
  --argjson nvme0 "$nvme0_temp" \
  --argjson nvme1 "$nvme1_temp" \
  --argjson pumpRpm "$pump_rpm" \
  --argjson aioFanRpm "$aio_fan_rpm" \
  --argjson boardFan2Rpm "$board_fan2_rpm" \
  --argjson boardFan7Rpm "$board_fan7_rpm" \
  --argjson coolantTemp "$coolant_temp" \
  '{
    cpu: $cpu,
    cpuTemp: $cpuTemp,
    cpuModel: $cpuModel,
    memoryPercent: $memoryPercent,
    memoryUsed: $memoryUsed,
    memoryTotal: $memoryTotal,
    gpu: $gpu,
    gpuTemp: $gpuTemp,
    gpuMemoryUsed: $gpuMemoryUsed,
    gpuMemoryTotal: $gpuMemoryTotal,
    gpuModel: $gpuModel,
    nvme0: $nvme0,
    nvme1: $nvme1,
    nvme0Model: $nvme0Model,
    nvme1Model: $nvme1Model,
    pumpRpm: $pumpRpm,
    aioFanRpm: $aioFanRpm,
    boardFan2Rpm: $boardFan2Rpm,
    boardFan7Rpm: $boardFan7Rpm,
    coolantTemp: $coolantTemp,
    pumpModel: $pumpModel,
    boardModel: $boardModel
  }'
