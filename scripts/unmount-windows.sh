#!/usr/bin/env bash
# unmount-windows.sh — Safely unmount Windows partitions
set -euo pipefail

RESCUE_DIR="/opt/rescue"
MOUNT_POINT="/mnt/windows"
STATUS_FILE="${RESCUE_DIR}/config/mount-status.txt"
BITLOCKER_MOUNT="/mnt/bitlocker"

echo "[$(date)] Unmounting..." | tee "${RESCUE_DIR}/logs/unmount.log"

sync

# Unmount Windows
umount "${MOUNT_POINT}" 2>/dev/null && echo "[✅] Windows unmounted." | tee -a "${RESCUE_DIR}/logs/unmount.log" || echo "[!] Nothing to unmount at ${MOUNT_POINT}." | tee -a "${RESCUE_DIR}/logs/unmount.log"

# Unmount BitLocker if mounted
umount "${BITLOCKER_MOUNT}" 2>/dev/null || true

# Clean up status files
rm -f "${STATUS_FILE}"
echo "[🧹] Status files cleaned." | tee -a "${RESCUE_DIR}/logs/unmount.log"
