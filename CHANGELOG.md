# Changelog

All notable changes to RedSeek Rescue will be documented in this file.

## [1.4.2] — 2026-07-05

### Fixed (Security)
- **🔴 API key no longer embedded in ISO** — build.sh stopped reading builder's `~/.hermes/config.yaml`. Key is user-provided at first boot (placeholder remains).
- **🔴 Shell injection in registry-tools.sh** — `SERVICE_NAME` now passed via environment variable, not interpolated into Python code.
- **🔴 Syntax errors in reset-password.sh** — 3 malformed variable expansions (`}` → `"`) fixed.
- **🔴 Case-insensitive Windows paths** — reset-password.sh now detects `Windows/System32/config` regardless of case via `find -iname`.
- **🔴 rescue-prompt.txt sed injection** — API key insertion uses Python instead of `sed` to avoid shell escaping issues.

### Fixed (Build)
- **build.sh** — removed `sudo lb config` (creates root-owned files); fallback retry with sudo only if first attempt fails + `chown` fixup.
- **ISO bootability verified** — `xorriso -report_el_torito` check after build.
- **Dependency check** — graceful check instead of silent `apt-get 2>/dev/null || true`.
- **ISO_NAME** updated to v1.4.2 (was v1.0 hardcoded).

### Fixed (Scripts)
- All 15 scripts now use `set -euo pipefail` consistently.
- `wifi-connect.sh` — password no longer exposed in `/proc/*/cmdline` (uses `nmcli --ask` with stdin pipe).
- `shadow-copy.sh` — fixed syntax error in log path.

### Added
- **GitHub Actions CI** — ShellCheck, bash syntax check, secret scanning, Trivy vulnerability scan, markdown lint.
- **CI badge** in README.

## [1.3.0] — 2026-07-04

### Fixed
- **ISO bootabil hibrid (BIOS + UEFI)** — El Torito boot catalog funcțional
- live-build 3.0 produce ISO fără boot → build manual cu xorriso
- GRUB BIOS via core.img + GRUB EFI via BOOTx64.EFI

### Added
- Script `make-iso.sh` pentru build manual post-live-build
- Suport GPT hybrid ISO (bootabil de pe USB fără `dd` special)

## [1.1.0] — 2026-07-04

### Added (TOP 5 — DeepSeek + Gemini collaboration)
- **rescue-playbook.sh** — Intelligent symptom-to-fix orchestrator.
- **snapshot-system.sh** — Backup critical Windows files before repairs.
- **rescue-gui.sh** — Zenity-based graphical interface.
- **auto-diagnose.sh** — Intelligent problem detection.
- **repair-boot.sh** — Windows boot repair from Linux.

### Changed
- Added `zenity` to build dependencies
- Build script now includes 21 rescue scripts (up from 16)

## [1.0.2] — 2026-07-04

### Fixed
- **Case-insensitive Windows paths** — better path resolution
- **Fast Startup / hibernation detection** — mount status checks
- **USB detection in backup** — uses `lsblk -no RM` for real removable drives

### Added
- **`--remove-hiberfile` flag** in `mount-windows.sh`
- **`scripts/utils.sh`** — shared helper library

## [1.0.1] — 2026-07-04

### Fixed
- **isohybrid missing from build** — added `syslinux-utils` to build dependencies

## [1.0.0] — 2026-07-03

### Added
- Initial release — 16 rescue scripts, Ubuntu Noble live-build, Hermes Agent + DeepSeek v4
