#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

GPU_VENDOR="unknown"   # amd | nvidia | intel | unknown

if cmd_exists lspci; then
    _gpu_line="$(lspci -nn 2>/dev/null | grep -Ei 'VGA compatible controller|3D controller' | head -1)"
    case "$_gpu_line" in
        *"[10de]"*) GPU_VENDOR="nvidia" ;;
        *"[1002]"*) GPU_VENDOR="amd" ;;
        *"[8086]"*) GPU_VENDOR="intel" ;;
    esac
else
    log_warn "lspci introuvable (paquet pciutils manquant) — détection GPU ignorée, GPU_VENDOR=unknown"
fi

export GPU_VENDOR
log_info "GPU détecté : $GPU_VENDOR"
