#!/usr/bin/env bash
# Copyright (c) 2026 Rednic Vasile
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - utils.sh
# Funcții helper globale, culori de jurnalizare, validări root
set -euo pipefail

# ─── Constante globale (centralizate) ───
MOUNT_BASE="${MOUNT_BASE:-/mnt/windows}"
BITLOCKER_DIR="${BITLOCKER_DIR:-/mnt/bitlocker}"
VSS_DIR="${VSS_DIR:-/mnt/vss}"
VSS_MOUNT="${VSS_MOUNT:-/mnt/shadow_mount}"
SNAPSHOT_DIR="${SNAPSHOT_DIR:-/tmp/registry_snapshots}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[*]${NC} $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
log_error()   { echo -e "${RED}[✗]${NC} $*" >&2; }

# Compatibilitate: alias log_warning -> log_warn
log_warning() { log_warn "$*"; }

require_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Acest script trebuie rulat ca root (sudo)."
        exit 1
    fi
}

# Verifică dacă PIPESTATUS e curat (toate 0)
check_pipe() {
    local statuses=("${PIPESTATUS[@]}")
    for st in "${statuses[@]}"; do
        if [ "$st" -ne 0 ]; then return 1; fi
    done
    return 0
}

# Verifică dacă un mount point e read-only
is_readonly() {
    local mp="$1"
    grep -q "[^ ]* $mp [^ ]* ro," /proc/mounts 2>/dev/null
}

# Sentinel path pentru snapshot obligatoriu
SNAPSHOT_SENTINEL="/opt/rescue/.snapshot_taken"

# Forțează snapshot înainte de operații distructive
require_snapshot() {
    if [ ! -f "$SNAPSHOT_SENTINEL" ]; then
        log_error "Snapshot necesar înainte de operația distructivă."
        log_error "Rulează: snapshot-system.sh"
        exit 1
    fi
}

# Căutare case-insensitive — parcurge calea pas cu pas
# Folosește bash globbing (nocaseglob) în loc de find pentru viteză
# Exemplu: find_ci /mnt/windows "Windows/System32/config"
find_ci() {
    local base="$1"
    local path="$2"
    local current="$base"

    # Save and set shell options for case-insensitive globbing
    local old_nocaseglob old_nullglob
    old_nocaseglob=$(shopt -p nocaseglob 2>/dev/null || true)
    old_nullglob=$(shopt -p nullglob 2>/dev/null || true)
    shopt -s nocaseglob nullglob

    IFS='/' read -ra parts <<< "$path"
    for part in "${parts[@]}"; do
        if [ -z "$part" ]; then continue; fi
        # Glob expands case-insensitively; take the first match
        local candidates=("${current}"/${part})
        if [ ${#candidates[@]} -eq 0 ]; then
            # Restore shell options before returning
            eval "$old_nocaseglob" 2>/dev/null || true
            eval "$old_nullglob" 2>/dev/null || true
            echo ""
            return 0
        fi
        current="${candidates[0]}"
    done

    # Restore shell options
    eval "$old_nocaseglob" 2>/dev/null || true
    eval "$old_nullglob" 2>/dev/null || true
    echo "$current"
}
