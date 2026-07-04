# Changelog

All notable changes to RedSeek Rescue will be documented in this file.

## [1.1.0] — 2026-07-04

### Added (TOP 5 — DeepSeek + Gemini collaboration)
- **rescue-playbook.sh** — Intelligent symptom-to-fix orchestrator. User describes symptom ("boot loop", "bluescreen", "virus"), playbook runs the correct scripts in order. 12 predefined playbooks + full diagnostic mode.
- **snapshot-system.sh** — Backup critical Windows files (registry hives, BCD, boot files) before repairs. Timestamped snapshots with one-command rollback.
- **rescue-gui.sh** — Zenity-based graphical interface. One-Click Health Check + visual menu for all 12 repair categories. Auto-mounts Windows if needed.
- **auto-diagnose.sh** — Intelligent problem detection. Analyzes SMART, minidumps, Event Log, stuck updates, boot files, and registry hives. Generates ranked hypothesis with confidence scores.
- **repair-boot.sh** — Windows boot repair from Linux. Detects EFI/BIOS mode, checks MBR/BCD/winload/ntoskrnl, verifies critical drivers. Suggests Windows recovery commands for missing files.

### Changed
- Added `zenity` to build dependencies (for GUI mode)
- Build script now includes 21 rescue scripts (up from 16)

## [1.0.2] — 2026-07-04

### Fixed
- **Case-insensitive Windows paths** — `check-windows.sh` and `parse-evtx.sh` now resolve paths case-insensitively.
- **Fast Startup / hibernation detection** — `cleanup-updates.sh` checks mount status before writes.
- **USB detection in backup** — `backup-data.sh` uses `lsblk -no RM` for real removable drives.

### Added
- **`--remove-hiberfile` flag** in `mount-windows.sh`
- **`scripts/utils.sh`** — shared helper library

## [1.0.1] — 2026-07-04

### Fixed
- **isohybrid missing from build** — added `syslinux-utils` to build dependencies

## [1.0.0] — 2026-07-03

### Added
- Initial release — 16 rescue scripts, Ubuntu Noble live-build, Hermes Agent + DeepSeek v4
