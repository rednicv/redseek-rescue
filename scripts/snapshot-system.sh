#!/usr/bin/env bash
# Copyright (c) 2026 rednicv
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - snapshot-system.sh
# Copie de siguranță a registry-ului înainte de operații

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

MOUNT_BASE="/mnt/windows"
SNAP_DIR="/tmp/registry_snapshots"
mkdir -p "$SNAP_DIR"

CONFIG_PATH=$(find_ci "$MOUNT_BASE" "Windows/System32/config")

if [ -n "$CONFIG_PATH" ] && [ -d "$CONFIG_PATH" ]; then
    log_info "Salvare snapshot registru..."
    cp -a "$CONFIG_PATH"/* "$SNAP_DIR/"
    touch "$SNAPSHOT_SENTINEL"
    log_success "Snapshot salvat în $SNAP_DIR"
fi
