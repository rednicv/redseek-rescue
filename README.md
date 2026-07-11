<p align="center">
  <img src="assets/banner.svg" alt="RedSeek Rescue Banner" width="100%">
</p>

# RedSeek Rescue [![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](/LICENSE) [![Version](https://img.shields.io/badge/version-1.4.15-blue.svg)](https://github.com/rednicv/redseek-rescue/releases) [![CI](https://github.com/rednicv/redseek-rescue/actions/workflows/ci.yml/badge.svg)](https://github.com/rednicv/redseek-rescue/actions/workflows/ci.yml) [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

**AI-powered bootable USB for Windows system repair.**

Boot from USB, run diagnostics, fix Windows — all from Linux, with an AI agent guiding you. No need to boot a broken Windows install.

Built with **[Hermes Agent](https://github.com/NousResearch/hermes-agent)** + **DeepSeek** on a lightweight Ubuntu Live environment.

```text
  ┌──────────┐     ┌──────────┐     ┌───────────┐     ┌──────────┐
  │  Boot    │────▶│  WiFi    │────▶│  Paste    │────▶│  Fix     │
  │  from    │     │  setup   │     │  DeepSeek │     │  Windows │
  │  USB     │     │          │     │  key      │     │          │
  └──────────┘     └──────────┘     └───────────┘     └──────────┘
                         │
                         └──▶ Manual mode (no AI needed)
```

---

## 🚀 What It Does

- **Boots from USB** — don't touch the broken Windows
- **AI assistant** — describes problems, suggests fixes, runs tools for you
- **All-in-one toolkit** — diagnostics, antivirus, registry editing, password recovery, and more
- **Offline-capable** — works without internet for most tools; AI needs connectivity
- **Safe by design** — read-only checks first, backups before changes, case-insensitive NTFS handling

## 🧰 Tools Included

| Category | Tools | Scripts |
|---|---|---|
| **Mount & Access** | NTFS mount (ntfs3/ntfs-3g), BitLocker decryption (dislocker), Volume Shadow Copy, hiberfile removal | `mount-windows.sh`, `unmount-windows.sh`, `shadow-copy.sh` |
| **Diagnostics** | SMART disk health, RAM test, CPU stress, temperatures, boot file integrity, BSOD minidump analysis | `diagnose.sh`, `check-windows.sh`, `hardware-diagnostics.sh` |
| **Antivirus** | ClamAV, chkrootkit, rkhunter; Wine-based portable AV downloader | `scan-windows.sh`, `download-antivirus.sh` |
| **Windows Repair** | Offline registry editor (hivex), stuck-updates cleanup, file signature verification | `registry-tools.sh`, `cleanup-updates.sh`, `verify-files.sh` |
| **Data Recovery** | Restore points mounting, backup to USB/cloud (rclone), Event Log parser | `backup-data.sh`, `parse-evtx.sh` |
| **Password Recovery** | chntpw + utilman.exe hack | `reset-password.sh` |
| **Connectivity** | WiFi setup from terminal with universal firmware | `wifi-connect.sh` |

All scripts handle case-insensitive NTFS paths and detect read-only mounts (Fast Startup/hibernation).

## 📦 Quick Start

### Requirements

- **Build machine:** Linux amd64 (Ubuntu/Debian, including WSL2), 4+ GB RAM, 10 GB free disk
- **Target machine:** Any PC that can boot from USB (BIOS or UEFI)

### Build

```bash
sudo apt update && sudo apt install -y live-build syslinux-utils python3-yaml git
git clone https://github.com/rednicv/redseek-rescue.git
cd redseek-rescue
./build.sh
```

> ⚠️ **WSL2 pitfalls:** Clone inside `~/` (Linux filesystem), NOT `/mnt/c/`. Install `syslinux-utils` before building (isohybrid).

### Write to USB

> 📀 **Step-by-step guide with screenshots:** See **[INSTALL.md](INSTALL.md)** — covers Rufus, BIOS setup, and troubleshooting.

Quick reference:

1. Download the ISO
2. **Rufus** (Windows) → select ISO → Write
3. Or use `dd` on Linux/macOS (see INSTALL.md)

### Boot

1. Insert USB into the broken PC
2. Enter BIOS/UEFI (F2/F12/Del at boot)
3. Select USB as boot device
4. Hermes starts automatically — asks for your DeepSeek API key
5. Get a free key at [platform.deepseek.com/api_keys](https://platform.deepseek.com/api_keys)

## 📁 Project Structure

```
redseek-rescue/
├── build.sh                     # ISO build script
├── config/
│   ├── hermes-config.yaml       # Hermes agent config
│   └── rescue-prompt.txt        # System prompt for the AI rescue agent
├── scripts/
│   ├── utils.sh                 # Shared helpers (find_ci, verify_mount, is_readonly)
│   ├── mount-windows.sh         # Mount NTFS, BitLocker, remove hiberfile
│   ├── unmount-windows.sh       # Safe unmount
│   ├── diagnose.sh              # Quick/full system diagnostics
│   ├── check-windows.sh         # Deep Windows filesystem check (case-insensitive)
│   ├── registry-tools.sh        # Offline registry editing
│   ├── reset-password.sh        # Windows password removal/reset
│   ├── parse-evtx.sh            # Event Log → JSON (case-insensitive paths)
│   ├── cleanup-updates.sh       # Fix stuck Windows updates (RO-aware)
│   ├── shadow-copy.sh           # Mount restore points
│   ├── verify-files.sh          # System file signature check
│   ├── scan-windows.sh          # ClamAV virus scan
│   ├── download-antivirus.sh    # Portable AV via Wine
│   ├── backup-data.sh           # Backup to USB (removable-only) or cloud (rclone)
│   ├── hardware-diagnostics.sh  # RAM, CPU, disk stress tests
│   └── wifi-connect.sh          # WiFi setup
├── iso-overlay/                 # Extra files for the ISO
└── output/                      # Built ISOs
```

## 🔧 Tech Stack

- **Base:** Ubuntu Noble (24.04) live-build
- **AI:** [Hermes Agent](https://github.com/NousResearch/hermes-agent) with DeepSeek v4
- **Key packages:** ntfs-3g, dislocker, chntpw, python3-hivex, python3-evtx, ClamAV, testdisk, smartmontools, libvshadow, osslsigncode, Wine, rclone

## ⚠️ Limitations

- **Build must be on amd64** — cross-architecture builds not supported
- **BitLocker** requires recovery key (48-digit) or password
- **Wine-based AV tools** may have limited detection vs native Windows
- **AI needs internet** — DeepSeek API runs in the cloud
- **Fast Startup** can cause read-only mounts — use `--remove-hiberfile` or shut down Windows fully

## 📝 License

MIT — do whatever you want, just keep the attribution. See [LICENSE](LICENSE).

## 📋 Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

---

**by [rednic](https://github.com/rednicv)** — because reinstalling Windows is giving up.
