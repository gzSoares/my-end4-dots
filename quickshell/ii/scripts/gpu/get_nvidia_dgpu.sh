#!/usr/bin/env bash
set -euo pipefail
LC_NUMERIC=C

# NVIDIA dGPU monitoring via nvidia-smi

# Check if nvidia-smi is available
if ! command -v nvidia-smi &> /dev/null; then
  echo '{}'
  exit 0
fi

# Se a GPU está suspensa (runtime PM), não consultar o nvidia-smi: isso a
# acordaria. Devolve um JSON "ocioso" (e não {}) para o shell continuar
# considerando a GPU disponível quando ela voltar a ser usada.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/nvidia_power.sh"
NAME_CACHE="${XDG_RUNTIME_DIR:-/tmp}/qs-nvidia-gpu-name"
if nvidia_all_suspended; then
  idle_name="$(cat "$NAME_CACHE" 2>/dev/null || true)"
  idle_name="${idle_name:-NVIDIA GPU}"
  idle_name="${idle_name//\"/\\\"}"
  printf '{"vendor": "nvidia", "name": "%s", "usagePercent": 0, "vramUsedGB": 0.0, "vramTotalGB": 0.0, "vramPercent": 0, "tempEdgeC": null, "tempJunctionC": null, "tempMemC": null, "fanRpm": null, "fanPercent": null, "powerW": null, "powerLimitW": null}\n' "$idle_name"
  exit 0
fi

# Query all GPU info in one call. nvidia-smi prints its failure text to
# stdout, so gate on the exit code rather than the output.
if ! query_out=$(nvidia-smi \
  --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,power.limit,fan.speed \
  --format=csv,noheader,nounits 2>/dev/null); then
  echo '{}'
  exit 0
fi
query_out=${query_out%%$'\n'*}
if [[ -z "$query_out" ]]; then
  echo '{}'
  exit 0
fi
IFS=',' read -r gpu_name gpu_usage vram_used_mib vram_total_mib temperature power_draw power_limit fan_speed <<< "$query_out"

# Fields report "[N/A]"/"[Not Supported]" on some cards — map non-numeric values
num_or() { local v="${1//[[:space:]]/}"; [[ "$v" =~ ^[0-9.]+$ ]] && echo "$v" || echo "$2"; }
gpu_name="${gpu_name:-NVIDIA GPU}"
printf '%s' "$gpu_name" > "$NAME_CACHE" 2>/dev/null || true
gpu_usage=$(num_or "${gpu_usage:-}" 0)
vram_used_mib=$(num_or "${vram_used_mib:-}" 0)
vram_total_mib=$(num_or "${vram_total_mib:-}" 0)
temperature=$(num_or "${temperature:-}" null)
power_draw=$(num_or "${power_draw:-}" null)
power_limit=$(num_or "${power_limit:-}" null)
fan_speed=$(num_or "${fan_speed:-}" null)

# Convert MiB to GB
vram_used_gb=$(awk -v u="$vram_used_mib" 'BEGIN{printf "%.1f", u/1024}')
vram_total_gb=$(awk -v t="$vram_total_mib" 'BEGIN{printf "%.1f", t/1024}')

# Calculate VRAM percentage
if [[ "$vram_total_mib" -gt 0 ]]; then
  vram_percent=$(awk -v u="$vram_used_mib" -v t="$vram_total_mib" 'BEGIN{printf "%.0f", (u/t)*100}')
else
  vram_percent=0
fi

# Escape GPU name for JSON
gpu_name_json=${gpu_name//\"/\\\"}

# Output JSON
printf '{'
printf '"vendor": "nvidia", '
printf '"name": "%s", ' "$gpu_name_json"
printf '"usagePercent": %d, ' "$gpu_usage"
printf '"vramUsedGB": %.1f, ' "$vram_used_gb"
printf '"vramTotalGB": %.1f, ' "$vram_total_gb"
printf '"vramPercent": %d, ' "$vram_percent"
printf '"tempEdgeC": %s, ' "${temperature}"
printf '"tempJunctionC": null, '
printf '"tempMemC": null, '
printf '"fanRpm": null, '
printf '"fanPercent": %s, ' "${fan_speed}"
printf '"powerW": %s, ' "${power_draw}"
printf '"powerLimitW": %s' "${power_limit}"
printf '}\n'
