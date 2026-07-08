#!/usr/bin/env bash
# Copyright (c) 2026 rednicv
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - diagnose.sh
# Verificare SMART, resurse sistem, colectare date esențiale

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

log_info "=== DIAGNOZĂ SMART DISK ==="
for disk in $(lsblk -dno NAME | grep -E '^sd|^nvme|^vd'); do
    log_info "Verificare /dev/$disk:"
    smartctl -H "/dev/$disk" || log_warn "Probleme detectate pe /dev/$disk"
done

log_info "=== VERIFICARE MEMORIE ȘI PROCESOR ==="
free -m
uptime
stress-ng --cpu 2 --timeout 5s --metrics || true
