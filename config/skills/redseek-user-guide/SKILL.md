---
name: redseek-user-guide
description: "Ghid complet pentru utilizatorul RedSeek Rescue — pași, opțiuni, troubleshooting."
version: 1.0.0
---

# RedSeek Rescue — Ghidul utilizatorului

Bine ai venit! Sunt pe un stick USB și te ajut să repari un Windows stricat — fără să-l pornești.

## Ce pot face

| Problemă | Soluție |
|---|---|
| Windows nu pornește | Diagnoză boot, registry, fișiere sistem |
| Virus/blocat | Antivirus (ClamAV + MalwareBytes via Wine) |
| Ai uitat parola | Resetare parolă Windows |
| Update blocat | Curățare update-uri blocate |
| Pierdut fișiere | Backup pe USB sau cloud (Google Drive etc.) |
| Discuri cu probleme | Testare SMART, RAM, CPU |
| BitLocker activ | Acces cu recovery key |

## Pași la prima utilizare

1. **Bootezi de pe stick** — intri în BIOS (F2/F12/Del la pornire) și alegi USB-ul
2. **WiFi** — te ajut să te conectezi la internet
3. **Cheie DeepSeek** (gratis) — îți faci cont pe platform.deepseek.com, iei cheia API, o lipești aici
4. **Diagnosticare** — rulez automat un diagnostic și-ți spun ce-am găsit
5. **Reparăm** — îmi spui ce problemă ai și te ghidez pas cu pas

## Dacă nu vrei să folosești AI-ul

Tastează `skip` când îți cer cheia DeepSeek. Intri în **mod manual** — vezi lista de tool-uri și rulezi ce ai nevoie. Toate scripturile sunt în `/opt/rescue/scripts/`.

## Comenzi rapide

| Ce vrei | Tastezi |
|---|---|
| Repornești asistentul AI | `hermes` |
| Ieși la terminal (shell) | `manual` |
| Terminal nou | Alt+F2 |
| WiFi manual | `nmtui` |
| Oprești PC-ul | `sudo poweroff` |
| Repornești PC-ul | `sudo reboot` |

## Ce NU face RedSeek Rescue

- **Nu șterge fișiere fără să te întrebe** — înainte de orice operație distructivă, îți cer confirmarea
- **Nu repară hardware defect** — dacă discul e stricat fizic, ai nevoie de service
- **Nu sparge BitLocker fără recovery key** — ai nevoie de cheia de 48 de cifre
- **Nu funcționează fără internet** (în mod AI) — ai nevoie de WiFi pentru DeepSeek

## Troubleshooting rapid

| Problemă | Rezolvare |
|---|---|
| Nu văd WiFi-ul | `nmtui` — interfață grafică pentru rețea |
| Hermes s-a blocat | Ctrl+C, apoi tastează `hermes` |
| Nu recunoaște discul | `sudo fdisk -l` — vezi toate discurile |
| Ecran negru la boot | Verifică în BIOS: Secure Boot OFF, Legacy Boot ON |
| BitLocker detectat | Pregătește recovery key-ul (cont Microsoft → Devices) |
