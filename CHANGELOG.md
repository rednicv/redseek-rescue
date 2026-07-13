# Changelog

All notable changes to RedSeek Rescue will be documented in this file.

## [1.6.0] — 2026-07-13

### Optimized (Opus 4.6 & Gemini 3.5 Refactors)
- **Case-Insensitive Path Resolution Optimization** — Replaced sequential `find` sub-processes in `find_ci` with optimized native bash globbing (`nocaseglob` + `nullglob`) for faster directory traversal on deep NTFS volumes.
- **BitLocker Input Validation** — Added 48-digit format verification (with hyphen-removal and whitespace trimming) and retry limits to the recovery key prompt. Passed the key via stdin to `dislocker-fuse` to prevent command-line exposure.
- **Unified Registry Verification** — Consolidated transaction log (`.LOG`, `.LOG1`, etc.) checking into a single bash validation layer, removing redundant logic from the Python sub-process.
- **Virtual Machine CPU Stress bypass** — Skip `stress-ng` CPU stress-testing when virtualization is detected (using `systemd-detect-virt`) to prevent Kernel RCU CPU Stalls under VirtualBox/Hyper-V.
- **ISO Build Robustness** — Merged `isohybrid` bypass and automatic `make-iso.sh` fallback from `v1.4.1-fixes` into the main `build.sh` script to ensure successful compilation under Debian/Ubuntu systems with nested path resolution.

## [1.4.18] — 2026-07-12


### Added
- **Password credentials** — configured `rescue:rescue` user credentials in live-build chroot hooks and systemd services for secure local/SSH access.
- **Line Ending fixes** — synchronized Git and workspaces to enforce Unix LF endings across all boot scripts.

## [1.4.17] — 2026-07-12

### Fixed (Critical Boot Hangs & Crashes)
- **🔴 rescue-playbook.sh** — run scripts directly instead of using `$()`. Fixes boot freeze by letting the user interact with the hidden BitLocker decryption prompt.
- **🔴 registry-tools.sh** — defined `$SYSTEM_HIVE` (via `find_ci`) and `$FORCE_MODE` to fix crash on unbound variables under `set -u`.
- **🔴 build.sh (.profile)** — added `trap ERR` to drop safely to a recovery shell if any boot script crashes, preventing infinite getty login loops.
- **🟠 auto-diagnose.sh** — refactored to source `utils.sh`, check root, read version dynamically, and handle failures cleanly.
- **🟠 rescue-gui.sh** — added DISPLAY/WAYLAND_DISPLAY graphical check to prevent Zenity from crashing on minimal text-only consoles.
- **🟡 .gitattributes** — added to force `eol=lf` line endings on all `.sh` and `.bats` files, preventing Windows CRLF translation errors on boot.

## [1.4.15] — 2026-07-11

### Fixed (Security)
- **🔴 Shell injection in parse-evtx.sh** — `$SYS_EVTX` no longer interpolated into Python code string. Now passed via `sys.argv[1]` with quoted heredoc.
- **🔴 Shell injection in registry-tools.sh** — `$SYSTEM_HIVE` no longer interpolated into Python code string. Same fix as above.
- **🔴 Double-escaped bytes in registry-tools.sh** — `b'\\x00\\x00\\x00\\x00'` was double-escaped, producing wrong value. Fixed to `b'\x00\x00\x00\x00'`.
- **🟠 WiFi password exposure** — `wifi-connect.sh` password was visible in `/proc/*/cmdline`. Now uses `--ask` flag with stdin pipe fallback.

### Fixed (Code Quality)
- **Centralized constants** — `MOUNT_BASE`, `BITLOCKER_DIR`, `VSS_DIR`, `VSS_MOUNT`, `SNAPSHOT_DIR` now defined once in `utils.sh` instead of hardcoded in 18 scripts.
- **rescue-playbook.sh** — version no longer hardcoded as `1.5.0`, now reads from `VERSION` file.
- **make-iso.sh** — staging directory uses `mktemp -d` instead of hardcoded `/tmp/iso-staging` (avoids tmpfs OOM and TOCTOU).
- **backup-data.sh** — USB mount now requires user confirmation before proceeding.

### Fixed (Documentation)
- **SECURITY.md** — updated supported versions from `1.0.x` to `1.4.x`.
- **CHANGELOG.md** — added v1.4.15 entry.
- **ci.yml** — fixed truncated permissions check job.

### Improved (Tests)
- **utils.bats** — extended with tests for `find_ci`, `is_readonly`, `check_pipe`.
- **scripts.bats** — new test file validating syntax and `--help` for all scripts.

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
