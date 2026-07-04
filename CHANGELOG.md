# Changelog

All notable changes to RedSeek Rescue will be documented in this file.

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
