#!/usr/bin/env bash
# utils.sh — Common helper functions for RedSeek Rescue scripts
# Source this in other scripts: source "$(dirname "$0")/utils.sh"

MOUNT="/mnt/windows"
LOGS_DIR="/opt/rescue/logs"
STATUS_FILE="/opt/rescue/config/mount-status.txt"

# Case-insensitive find — handles Windows/windows, System32/system32, etc.
# Usage: find_ci <base_dir> <maxdepth> <name_pattern>
find_ci() {
    find "$1" -maxdepth "$2" -iname "$3" 2>/dev/null | head -n1
}

# Verify Windows is mounted, exit gracefully if not
# Usage: verify_mount || exit 1
verify_mount() {
    if ! mountpoint -q "${MOUNT}"; then
        echo "[!] Windows not mounted at ${MOUNT}. Run mount-windows.sh first."
        return 1
    fi
    return 0
}

# Check if mount is read-only
# Returns 0 (true) if RO, 1 (false) if RW
is_readonly() {
    if [ -f "${STATUS_FILE}" ]; then
        grep -q "ro" "${STATUS_FILE}" 2>/dev/null && return 0
    fi
    return 1
}
