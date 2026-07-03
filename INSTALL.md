# 📀 RedSeek Rescue — Installation Guide

A step-by-step guide to create your rescue USB and boot from it. No Linux knowledge required.

---

## What You Need

- A working computer (any OS) to create the USB
- A USB stick (8 GB or larger)
- The broken computer you want to fix
- (Optional) A DeepSeek API key from [platform.deepseek.com](https://platform.deepseek.com/api_keys) — free credits on signup

---

## Step 1: Download the ISO

Go to [GitHub Releases](https://github.com/rednicv/redseek-rescue/releases) and download the latest `redseek-rescue-v1.0.iso` (~1.5 GB).

---

## Step 2: Download and Install Rufus

Rufus is the recommended tool for writing the ISO to USB on Windows.

1. Go to https://rufus.ie
2. Download the latest version (rufus-x.x.exe)
3. Run it — **no installation needed**, it's portable

![Rufus download page — click the first link](https://rufus.ie/pics/rufus_en.png)

---

## Step 3: Write the ISO to USB

1. **Insert your USB stick** into the working computer
2. **Open Rufus** (double-click the .exe file you downloaded)
3. Click the **SELECT** button and choose `redseek-rescue-v1.0.iso`
4. Under "Partition scheme", leave it on **MBR** (works on most PCs)
5. Under "Target system", leave it on **BIOS or UEFI**
6. Click **START**
7. ⚠️ **IMPORTANT:** If Rufus asks *"Write in ISO Image mode or DD Image mode?"*, choose **DD Image mode**!
8. Confirm any warnings (Rufus will erase the USB — make sure it's empty)

```
┌──────────────────────────────────────────┐
│              Rufus 4.x                   │
│                                          │
│  Device:  [USB Drive (16 GB)]      ▾     │
│  ──────────────────────────────          │
│  Boot selection:                         │
│  [redseek-rescue-v1.0.iso]  [SELECT]     │
│  ──────────────────────────────          │
│  Partition scheme:  [MBR]          ▾     │
│  Target system:     [BIOS or UEFI] ▾     │
│  ──────────────────────────────          │
│  Volume label:      [REDSEEK_RESCUE]     │
│  File system:       [FAT32]        ▾     │
│                                          │
│  [START]                                 │
│                                          │
│  Status: Ready                           │
└──────────────────────────────────────────┘
```

Wait 5-10 minutes for Rufus to finish. When the status bar says "READY", your USB is done.

---

## Step 4: Boot from USB

1. **Insert the USB** into the broken computer
2. **Turn it on** (or restart)
3. **Immediately start tapping** one of these keys:
   - **F12** — most common (Dell, Lenovo, Acer, Gigabyte)
   - **F2** — ASUS, some Acer
   - **Del** — Desktop PCs, MSI
   - **Esc** — HP, some laptops
4. If you see the Windows logo, you missed it — restart and try again (faster!)
5. In the boot menu, select your USB drive (usually labeled "UEFI: <brand name>" or "USB Hard Drive")
6. Press Enter

```
┌──────────────────────────────────────┐
│         BOOT MENU                    │
│                                      │
│  1. Windows Boot Manager             │
│  2. UEFI: SanDisk Cruzer             │ ← SELECT THIS
│  3. UEFI: LAN                        │
│  4. Enter Setup                      │
│                                      │
│  ↑↓ to move  ENTER to select         │
└──────────────────────────────────────┘
```

---

## Step 5: What You'll See

After 30-60 seconds of loading:

```
╔═══════════════════════════════════════════╗
║      RedSeek Rescue by rednic            ║
║      AI-powered system rescue tool       ║
╚═══════════════════════════════════════════╝

Starting AI rescue agent...
```

Then Hermes will greet you and guide you through:
1. **WiFi setup** — connect to the internet
2. **API key** — paste your DeepSeek key (or type `skip` for manual mode)
3. **Diagnostics** — automatic system check
4. **Repair** — tell Hermes what's wrong and follow the instructions

---

## Step 6: Get a Free DeepSeek API Key (2 minutes)

If you don't have a key yet:

1. Go to https://platform.deepseek.com
2. Click **Sign Up** (use email or Google login)
3. Verify your email
4. Go to **API Keys** in the left sidebar
5. Click **Create new key**
6. Copy the key (starts with `sk-`)
7. Paste it into Hermes when asked

New accounts get free credits — no credit card needed for trial.

---

## Troubleshooting

| Problem | Solution |
|---|---|
| **Rufus says "Error: ISO image extraction failure"** | Try a different USB port. Or use balenaEtcher as alternative |
| **USB boots to black screen** | Enter BIOS setup (F2/Del), disable **Secure Boot**, enable **Legacy Boot** / **CSM** |
| **Boot menu doesn't show USB** | Try a different USB port (use rear ports on desktop). Some USB 3.0 ports need USB 2.0 |
| **"No operating system found"** | Rufus was in wrong mode. Re-write with **DD Image mode** |
| **WiFi not working** | Type `nmtui` in the terminal (Alt+F2 opens a new one) for graphical WiFi setup |
| **Hermes crashed / froze** | Press Ctrl+C, then type `hermes` to restart |
| **Stuck at loading screen** | Wait up to 2 minutes. Slow USB sticks take longer |

---

## Video Guide

*Coming soon*

---

## Need Help?

Open an issue on GitHub: https://github.com/rednicv/redseek-rescue/issues

---

**Next:** [README](README.md) — full project documentation and build instructions.
