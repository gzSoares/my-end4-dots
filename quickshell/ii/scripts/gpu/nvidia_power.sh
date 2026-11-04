#!/usr/bin/env bash
# Funções para saber se a dGPU NVIDIA está suspensa SEM acordá-la.
# Ler arquivos do sysfs não acorda a placa; chamar nvidia-smi acorda.
# Este arquivo é carregado com `source` pelos outros scripts desta pasta.

# Raiz do sysfs (sobrescrevível só para testes).
GPU_SYSFS_ROOT="${GPU_SYSFS_ROOT:-/sys}"

# Imprime o caminho sysfs de cada GPU NVIDIA (vendor 0x10de, classe 0x03xxxx).
nvidia_pci_devices() {
  local d
  for d in "$GPU_SYSFS_ROOT"/bus/pci/devices/*; do
    [[ "$(cat "$d/vendor" 2>/dev/null)" == "0x10de" ]] || continue
    [[ "$(cat "$d/class" 2>/dev/null)" == 0x03* ]] || continue
    printf '%s\n' "$d"
  done
}

# Retorna 0 se existe ao menos uma GPU NVIDIA e todas estão suspensas.
# Retorna 1 se alguma está ativa ou se não há GPU NVIDIA.
nvidia_all_suspended() {
  local d runtime pstate found=1
  while IFS= read -r d; do
    found=0
    runtime="$(cat "$d/power/runtime_status" 2>/dev/null || echo unknown)"
    pstate="$(cat "$d/power_state" 2>/dev/null || echo unknown)"
    pstate="${pstate,,}"   # o kernel escreve "D3cold"; comparar em minúsculas
    if [[ "$runtime" != "suspended" && "$pstate" != "d3cold" ]]; then
      return 1
    fi
  done < <(nvidia_pci_devices)
  return "$found"
}
