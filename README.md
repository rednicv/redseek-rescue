# RedSeek Rescue [![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT) [![Version](https://img.shields.io/badge/version-1.0-blue.svg)](https://github.com/rednicv/redseek-rescue/releases)

**AI-powered bootable USB for Windows system repair.**

Boot from USB, run diagnostics, fix Windows — all from Linux, with an AI agent guiding you. No need to boot a broken Windows install.

Built with **[Hermes Agent](https://github.com/NousResearch/hermes-agent)** + **DeepSeek** on a lightweight Ubuntu Live environment.

---

## 🚀 What It Does

- **Boots from USB** — don't touch the broken Windows
- **AI assistant** — describes problems, suggests fixes, runs tools for you
- **All-in-one toolkit** — diagnostics, antivirus, registry editing, password recovery, and more
- **Offline-capable** — works without internet for most tools; AI needs connectivity

## 🧰 Tools Included

| Category | Tools |
|---|---|
| **Mount & Access** | NTFS mount, BitLocker decryption (dislocker), Volume Shadow Copy |
| **Diagnostics** | SMART disk health, RAM test, CPU stress, temperatures, boot check |
| **Antivirus** | ClamAV, chkrootkit, rkhunter; Wine-based portable AV downloader |
| **Windows Repair** | Offline registry editor (hivex), stuck-updates cleanup, file signature verification |
| **Data Recovery** | Restore points mounting, backup to USB/cloud (rclone), Event Log parser |
| **Password Recovery** | chntpw + utilman.exe hack |
| **Connectivity** | WiFi setup from terminal |

Full list: see `scripts/` directory.

## 📦 Quick Start

### Requirements

- **Build machine:** Linux amd64 (Ubuntu/Debian recommended), 4+ GB RAM, 10 GB free disk
- **Target machine:** Any PC that can boot from USB (BIOS or UEFI)

### Build

```bash
# Install build dependencies (Ubuntu/Debian)
sudo apt update && sudo apt install -y live-build

# Clone and build
git clone git@github.com:rednicv/redseek-rescue.git
cd redseek-rescue

# Set your DeepSeek API key
# Edit config/hermes-config.yaml or let build.sh auto-detect it from ~/.hermes/config.yaml

./build.sh
# → output/redseek-rescue-v1.0.iso (~10-20 min)
```

### Write to USB

1. Download the ISO
2. **Rufus** (Windows) → select ISO → **DD Image mode** → Write
3. Or: `sudo dd if=redseek-rescue-v1.0.iso of=/dev/sdX bs=4M status=progress` (Linux/macOS)

### Boot

1. Insert USB into the broken PC
2. Enter BIOS/UEFI (F2/F12/Del at boot)
3. Select USB as boot device
4. Wait for Ubuntu Live to load
5. **Hermes starts automatically** — it will greet you and ask for a DeepSeek API key
6. Get a free key at [platform.deepseek.com/api_keys](https://platform.deepseek.com/api_keys) (free credits on signup)
7. Paste the key — Hermes saves it and starts diagnosing

## 📁 Project Structure

```
redseek-rescue/
├── build.sh                     # ISO build script
├── config/
│   ├── hermes-config.yaml       # Hermes agent config (set your DeepSeek key)
│   └── rescue-prompt.txt        # System prompt for the AI rescue agent
├── scripts/
│   ├── mount-windows.sh         # Mount NTFS partitions, detect BitLocker
│   ├── unmount-windows.sh       # Safe unmount
│   ├── diagnose.sh              # Quick/full system diagnostics
│   ├── check-windows.sh         # Deep Windows filesystem check
│   ├── registry-tools.sh        # Offline registry editing
│   ├── reset-password.sh        # Windows password removal/reset
│   ├── parse-evtx.sh            # Event Log → JSON
│   ├── cleanup-updates.sh       # Fix stuck Windows updates
│   ├── shadow-copy.sh           # Mount restore points
│   ├── verify-files.sh          # System file signature check
│   ├── scan-windows.sh          # ClamAV virus scan
│   ├── download-antivirus.sh    # Portable AV via Wine
│   ├── backup-data.sh           # Backup to USB or cloud (rclone)
│   ├── hardware-diagnostics.sh  # RAM, CPU, disk stress tests
│   └── wifi-connect.sh          # WiFi setup
├── iso-overlay/                 # Extra files for the ISO
└── output/                      # Built ISOs
    └── redseek-rescue-v1.0.iso
```

## 🔧 Tech Stack

- **Base:** Ubuntu Noble (24.04) live-build
- **AI:** [Hermes Agent](https://github.com/NousResearch/hermes-agent) with DeepSeek v4
- **Key packages:** ntfs-3g, dislocker, chntpw, python3-hivex, python3-evtx, ClamAV, testdisk, ddrescue, smartmontools, libvshadow, osslsigncode, Wine, rclone

## ⚠️ Limitations

- **Build must be on amd64** — cross-architecture builds (ARM → amd64) are not supported out of the box
- **BitLocker** requires the recovery key (48-digit) or password
- **Wine-based AV tools** may have limited detection rates compared to native Windows
- **AI needs internet** — DeepSeek API runs in the cloud

## 📝 License

MIT — do whatever you want, just keep the attribution. See [LICENSE](LICENSE).

---

**by [rednic](https://github.com/rednicv)** — because reinstalling Windows is giving up.
