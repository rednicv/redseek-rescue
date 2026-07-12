---
name: Bug report
about: Raportează o problemă pentru a ne ajuta să îmbunătățim RedSeek Rescue
title: '[BUG] '
labels: bug
assignees: ''
---

**Descrierea problemei**
O descriere clară și concisă a bug-ului.

**Pași pentru reproducere**
1. Rulează `./build.sh` (sau scriptul afectat)
2. Selectează opțiunea ...
3. Observă eroarea ...

**Comportament așteptat**
Ce ar fi trebuit să se întâmple.

**Comportament actual**
Ce s-a întâmplat de fapt.

**Loguri**
Dacă rulezi build.sh, atașează `build.log`. Pentru scripturi individuale, copiază output-ul terminalului.

```bash
# rulează din rădăcina proiectului
bash -n scripts/nume-script.sh
```

**Mediu (completează):**
- Mediu de boot: [Live ISO / VPS / VM]
- Arhitectură: [amd64 / arm64]
- Versiune ISO: [v1.5.0 / custom build]
- Versiune live-build: `dpkg -s live-build | grep Version`

**Context suplimentar**
Orice altceva relevant.
