# Changelog

All notable changes to RedSeek Rescue will be documented in this file.

## [1.0.2] — 2026-07-04

### Fixed
- **Case-insensitive Windows paths** — `check-windows.sh` and `parse-evtx.sh` now resolve `Windows/System32` case-insensitively (handles `windows/system32`, `WINDOWS/SYSTEM32`, etc. on real NTFS volumes).
- **Fast Startup / hibernation detection** — `cleanup-updates.sh` now checks mount status before attempting writes; exits gracefully with fix instructions if Windows is read-only.
- **USB detection in backup** — `backup-data.sh` now uses `lsblk -no RM` (removable flag) to detect real USB drives, no longer misidentifies internal HDDs/NVMe.

### Added
- **`--remove-hiberfile` flag** in `mount-windows.sh` — attempts to delete `hiberfil.sys` before mounting, fixing "Windows is hibernated" read-only mounts.
- **`scripts/utils.sh`** — shared helper library with `find_ci()`, `verify_mount()`, and `is_readonly()` functions used by all rescue scripts.
- **Expanded README tools table** — added detailed descriptions and script names for each tool category.

### Changed
- Refactored `check-windows.sh`, `parse-evtx.sh`, `cleanup-updates.sh`, `mount-windows.sh`, and `backup-data.sh` to source `utils.sh` instead of duplicating helper functions.

## [1.0.1] — 2026-07-04

### Fixed
- **isohybrid missing from build** — ISO was UEFI-only; Rufus rejected it as non-bootable. Added `syslinux-utils` to build dependencies so hybrid ISO (BIOS + UEFI) is generated correctly.

### Added
- **WSL2 build support** — documented step-by-step for building on Windows via WSL2 (Ubuntu).
- **WSL2 pitfalls** documented: clone in `~/` not `/mnt/c/`, install `syslinux-utils` before build, cache owned by root.

## [1.0.0] — 2026-07-03

### Added
- Initial release of RedSeek Rescue
- Ubuntu Noble (24.04) live-build base
- 16 rescue scripts for Windows repair
- Hermes Agent integration with DeepSeek v4
- Auto-start Hermes at boot with `.profile` recovery loop
- WiFi-first setup flow with `skip` option for manual mode
- Key-on-demand: Hermes asks for DeepSeek API key on first boot
- Universal WiFi firmware (Intel, Broadcom, Atheros) via `restricted` repo
- User guide skill (`redseek-user-guide`) loaded on the stick
- BitLocker support via `dislocker`
- ClamAV antivirus + Wine-based portable AV downloader
- Comprehensive INSTALL.md with Rufus tutorial
- Security policy and code of conduct

[1.0.0]: https://github.com/rednicv/redseek-rescue/releases/tag/v1.0.0
