## Descriere

O descriere clară a modificărilor propuse.

## Tip modificare

- [ ] Bug fix
- [ ] Feature nou
- [ ] Documentație
- [ ] Refactor / Code style
- [ ] CI/CD

## Listă de verificare

- [ ] Am rulat `bash -n` pe toate scripturile modificate (sintaxă corectă)
- [ ] Scripturile folosesc `source "${SCRIPT_DIR}/utils.sh"` și `require_root` acolo unde e cazul
- [ ] Căile de fișiere Windows sunt tratate **case-insensitive** (`find_ci()` / `iname`)
- [ ] Am verificat permisiunile (`chmod +x` pentru scripturi executabile)
- [ ] build.sh: `--mode ubuntu` e prezent la `lb config`
- [ ] make-iso.sh: EFI + BIOS boot funcțional (dacă e cazul)
- [ ] Am testat local și funcționează
- [ ] Am actualizat documentația dacă e necesar

## Testare

Cum ai testat modificările?

```bash
# exemplu
bash -n scripts/mount-windows.sh
```

## Issue asociată

Fixes # (dacă e cazul)
