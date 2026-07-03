#!/usr/bin/env bash
# unmount-windows.sh — Safely unmount Windows partitions
set -e

MOUNT_POINT="/mnt/windows"
echo "[$(date)] Unmounting ${MOUNT_POINT}..."
sync
umount "${MOUNT_POINT}" 2>/dev/null && echo "[✅] Unmounted." || echo "[!] Nothing to unmount."
