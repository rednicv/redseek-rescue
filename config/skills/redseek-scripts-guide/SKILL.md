---
name: redseek-scripts-guide
description: Ghidul scripturilor de diagnosticare și reparație disponibile în RedSeek Rescue. Activează acest skill pentru a rula diagnostice, reparații sau curățări de sistem.
---

# RedSeek Rescue Scripts Guide

Acest skill oferă informații despre toate scripturile disponibile în `/opt/rescue/scripts/` și cum să le rulezi în siguranță:

1. **`auto-diagnose.sh`**
   - **Cale:** `/opt/rescue/scripts/auto-diagnose.sh`
   - **Scop:** Rulează scanarea SMART a discurilor, verifică memoria și procesorul, detectează dacă rulează într-o mașină virtuală (și sare peste stress-ng), verifică integritatea partiției de Windows și starea Fast Startup.
   - **Rulare:** `sudo bash /opt/rescue/scripts/auto-diagnose.sh`

2. **`mount-windows.sh`**
   - **Cale:** `/opt/rescue/scripts/mount-windows.sh`
   - **Scop:** Montează partiția de Windows. Suportă deblocarea BitLocker (cere cheia de 48 de cifre și validează formatul).
   - **Rulare:** `sudo bash /opt/rescue/scripts/mount-windows.sh`

3. **`registry-tools.sh`**
   - **Cale:** `/opt/rescue/scripts/registry-tools.sh`
   - **Scop:** Analizează registry-ul Windows, curăță logurile de tranzacții și repară hives-urile Windows.
   - **Rulare:** `sudo bash /opt/rescue/scripts/registry-tools.sh`

4. **`rescue-playbook.sh`**
   - **Cale:** `/opt/rescue/scripts/rescue-playbook.sh`
   - **Scop:** Rulează întregul flux automat de diagnosticare și reparație.
   - **Rulare:** `sudo bash /opt/rescue/scripts/rescue-playbook.sh` (sau adaugă `--offline`)

Rulează oricare dintre aceste scripturi folosind comanda `sudo bash <cale-script>` în terminal când utilizatorul o cere.
