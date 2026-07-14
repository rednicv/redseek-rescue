

# RedSeek Rescue — Prezentare Tehnică

---

## **Când Windows-ul Cade, Linux-ul Ridică**
### *Un sistem de operare portabil, cu agent AI integrat, pentru salvarea instalațiilor Windows defecte*

---

**Versiune:** 1.8.0
**Repo:** [github.com/rednicv/redseek-rescue](https://github.com/rednicv/redseek-rescue)
**Bază:** Ubuntu Noble 24.04 LTS
**Data analizei:** 14 Iulie 2026

---

## 1. Ce Este RedSeek Rescue?

RedSeek Rescue este un **ISO bootabil** construit pe Ubuntu 24.04 LTS, proiectat cu un singur scop: **să repare instalații Windows care nu mai pornesc** — sau care pornesc, dar nu mai funcționează corect.

Ceea ce îl diferențiază de un live USB obișnuit:

- **Un agent AI integrat** (Hermes + DeepSeek) care ghidează utilizatorul pas cu pas — de la diagnostic la reparație — în limbaj natural, în română sau engleză.
- **18 scripturi de reparare** testate, care acoperă totul: de la montarea partițiilor NTFS și deblocarea BitLocker, până la scanare antivirus, editare registry offline și recuperare date.
- **Funcționare completă fără AI.** Nu ai cheie API? Nu ai internet? Toate scripturile rulează offline, manual. AI-ul e un ghid, nu o dependență.

> **Publicul țintă:** Tehnicieni de service, sysadmini, utilizatori avansați care trebuie să salveze un Windows fără a reinstala.

---

## 2. Arhitectura Sistemului

```
╔══════════════════════════════════════════════════════════════════╗
║                     RedSeek Rescue ISO (~3.1 GB)                ║
║                                                                  ║
║   ┌────────────────┐   ┌──────────────────┐   ┌──────────────┐  ║
║   │                │   │                  │   │              │  ║
║   │   Ubuntu 24.04 │   │  Hermes Agent    │   │  18 Scripturi│  ║
║   │   (live-build) │   │  v0.18.0         │   │  de Reparare │  ║
║   │                │   │                  │   │              │  ║
║   │  • SquashFS    │   │  • System Prompt │   │  • Montare   │  ║
║   │  • BIOS + UEFI │   │  • Skills YAML   │   │  • Diagnoza  │  ║
║   │  • amd64 only  │   │  • Flux ghidat   │   │  • Antivirus │  ║
║   │                │   │                  │   │  • Registry   │  ║
║   └───────┬────────┘   └────────┬─────────┘   │  • Backup    │  ║
║           │                     │              │  • Rețea     │  ║
║           │                     │              └──────┬───────┘  ║
║           └─────────────────────┼─────────────────────┘          ║
║                                 │                                ║
║                    ┌────────────▼────────────┐                   ║
║                    │                         │                   ║
║                    │    DeepSeek API v4      │                   ║
║                    │    (Flash / Pro)        │                   ║
║                    │                         │                   ║
║                    │    ⚠ OPȚIONAL           │                   ║
║                    │    Necesită internet     │                   ║
║                    │    + cheie API           │                   ║
║                    │                         │                   ║
║                    └─────────────────────────┘                   ║
╚══════════════════════════════════════════════════════════════════╝
```

**Trei piloni, un singur scop:**

| Pilon | Rol | Poate funcționa singur? |
|-------|-----|------------------------|
| **Ubuntu live** | Bootează mașina, oferă drivere și tools | ✅ Da |
| **Scripturi** | Execută operațiile efective de reparare | ✅ Da |
| **Hermes + DeepSeek** | Ghidează utilizatorul prin conversație | ⚠ Necesită internet |

---

## 3. Componente Principale

### 3.1 Sistemul de Operare — Fundația

| Parametru | Valoare |
|-----------|---------|
| **Distribuție** | Ubuntu Noble 24.04 LTS |
| **Build tool** | `live-build` |
| **Boot** | Dual: BIOS (MBR) + UEFI (El Torito) |
| **Arhitectură** | `amd64` exclusiv |
| **Compresie** | SquashFS (~2.9 GB comprimat) |
| **ISO final** | ~3.1 GB |

> **De ce Ubuntu 24.04?** LTS = suport pe termen lung. Kernel modern = suport hardware extins. `live-build` = tooling matur pentru ISO-uri personalizate.

---

### 3.2 Agentul AI — Hermes

Hermes nu e un chatbot generic. E un **agent configurat cu skill-uri specifice** pentru rescue operations.

```yaml
# Configurare: /opt/rescue/config/hermes-config.yaml

Agent:        Hermes v0.18.0
Model:        DeepSeek v4 (Flash sau Pro)
System Prompt: /opt/rescue/config/rescue-prompt.txt
Skills:
  - redseek-user-guide        # Ce poate face sistemul
  - redseek-scripts-guide     # Cum se folosesc scripturile (v1.6.1)
```

**Ce știe Hermes să facă:**
- Să detecteze limba utilizatorului și să răspundă corespunzător
- Să ruleze `diagnose.sh --quick` automat la pornire
- Să recomande scriptul potrivit pentru problema descrisă
- Să ceară confirmare explicită înainte de orice operație destructivă
- Să recunoască un utilizator stresat și să fie concis

**Ce NU face Hermes:**
- Nu inventează comenzi — folosește strict scripturile existente
- Nu rulează nimic fără confirmare
- Nu funcționează fără internet și cheie API DeepSeek

---

### 3.3 Scripturile de Reparare — 18 Unelte Specializate

Organizate pe categorii funcționale:

```
📂 Scripturi RedSeek Rescue
│
├── 🔧 MONTARE & ACCES
│   ├── mount-windows.sh        # Montează partiția Windows (NTFS)
│   ├── unmount-windows.sh      # Demontează curat
│   └── shadow-copy.sh          # Accesează Volume Shadow Copies (restore points)
│
├── 🔍 DIAGNOSTICARE
│   ├── diagnose.sh             # Diagnostic rapid (--quick) sau complet
│   ├── check-windows.sh        # Verifică integritatea instalării Windows
│   └── hardware-diagnostics.sh # SMART, memorie, senzori, stress test
│
├── 🛡️ ANTIVIRUS
│   ├── scan-windows.sh         # Scanare ClamAV pe partiția Windows
│   └── download-antivirus.sh   # Descarcă definiții actualizate
│
├── 🔨 REPARARE WINDOWS
│   ├── registry-tools.sh       # Editare registry offline (python3-hivex)
│   ├── cleanup-updates.sh      # Curăță update-uri Windows blocate
│   └── verify-files.sh         # Verifică integritatea fișierelor sistem
│
├── 💾 RECUPERARE DATE
│   ├── backup-data.sh          # Backup date utilizator (+ rclone pentru cloud)
│   └── parse-evtx.sh           # Convertește Event Logs (.evtx) → JSON
│
├── 🔑 RESETARE PAROLĂ
│   └── reset-password.sh       # Reset parolă cont Windows (offline)
│
├── 🌐 REȚEA
│   └── wifi-connect.sh         # Conectare WiFi (parolă securizată)
│
└── ⚙️ UTILITARE
    ├── utils.sh                # Funcții partajate (find_ci, validări, etc.)
    └── rescue-playbook.sh      # Orchestrare automată
```

---

## 4. Fluxul Agentului AI

Hermes urmează un **protocol strict** definit în system prompt. Nu improvizează.

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   UTILIZATOR BOOTEAZĂ ISO                                   │
│         │                                                   │
│         ▼                                                   │
│   ┌─────────────────┐                                       │
│   │  "Bun venit!"   │  Hermes se prezintă                   │
│   │  Pornește WiFi   │  wifi-connect.sh (dacă e nevoie)     │
│   └────────┬────────┘                                       │
│            ▼                                                │
│   ┌─────────────────┐     ┌──────────────────────────┐      │
│   │  Cheie API       │────▶│  NU → Mod Manual         │      │
│   │  DeepSeek?       │     │  (scripturile merg,      │      │
│   └────────┬────────┘     │   AI-ul nu)               │      │
│            │ DA            └──────────────────────────┘      │
│            ▼                                                │
│   ┌─────────────────┐                                       │
│   │  diagnose.sh     │  Diagnostic automat rapid             │
│   │  --quick         │                                       │
│   └────────┬────────┘                                       │
│            ▼                                                │
│   ┌─────────────────┐                                       │
│   │  "Care e        │  Hermes întreabă                      │
│   │   problema?"    │                                       │
│   └────────┬────────┘                                       │
│            ▼                                                │
│   ┌─────────────────┐                                       │
│   │  REPARARE        │  Hermes recomandă + execută           │
│   │  GHIDATĂ         │  scriptul potrivit                    │
│   │                  │                                       │
│   │  ⚠ Operații      │  Explică CE face                      │
│   │  destructive:    │  Cere CONFIRMARE                      │
│   │  BACKUP AUTOMAT  │  Face BACKUP înainte                  │
│   └────────┬────────┘                                       │
│            ▼                                                │
│   ┌─────────────────┐                                       │
│   │  ESCAPE HATCHES  │                                       │
│   │                  │                                       │
│   │  Ctrl+C → shell  │  Ieșire rapidă din agent              │
│   │  Alt+F2 → tty2   │  Terminal proaspăt                    │
│   └─────────────────┘                                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. Stiva Tehnologică

### Pachete critice incluse în ISO:

| Domeniu | Pachete | De ce contează |
|---------|---------|----------------|
| **Fișiere Windows** | `ntfs-3g`, `dislocker`, `exfatprogs` | Montare NTFS, deblocare BitLocker, suport exFAT |
| **Diagnosticare disc** | `smartmontools`, `hdparm`, `testdisk`, `gddrescue` | SMART health, performanță disc, recuperare partiții |
| **Diagnosticare hardware** | `memtester`, `stress-ng`, `lm-sensors` | Test memorie, stress CPU, temperaturi |
| **Antivirus** | `ClamAV`, `chkrootkit`, `rkhunter` | Scanare malware, rootkit detection |
| **Registry Windows** | `python3-hivex` | Editare offline a registry-ului Windows |
| **Event Logs** | `python3-evtx` | Parsing fișiere `.evtx` → JSON (analiză cauze) |
| **Shadow Copies** | `libvshadow-utils` | Acces la restore points Windows |
| **Cloud Backup** | `rclone` | Backup pe Google Drive, OneDrive, S3, etc. |
| **Verificare semnături** | `osslsigncode` | Verifică autenticitatea fișierelor Windows |
| **Drivere rețea** | `linux-firmware` | Intel, Atheros, Broadcom WiFi |

---

## 6. Securitate — Detalii de Implementare

Securitatea într-un tool de rescue nu e opțională. Un script greșit poate distruge ce încerci să salvezi.

### Măsuri implementate:

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  🔒  PATH-URI CASE-INSENSITIVE                                   │
│      Funcția find_ci() în utils.sh                               │
│      NTFS nu e case-sensitive → scripturile trebuie              │
│      să găsească "Windows", "windows", "WINDOWS"                │
│                                                                  │
│  🔒  DETECȚIE MOUNT READ-ONLY                                    │
│      Dacă Windows e hibernat (Fast Startup),                     │
│      partiția se montează read-only automat                      │
│      Soluție: --remove-hiberfile (cu confirmare)                 │
│                                                                  │
│  🔒  BACKUP AUTOMAT ÎNAINTE DE MODIFICĂRI                        │
│      Toate operațiile destructive creează backup                 │
│      Nicio excepție.                                             │
│                                                                  │
│  🔒  VALIDARE BITLOCKER                                          │
│      Recovery key validat: exact 48 digiți                       │
│      Cheia se transmite pe stdin, nu ca argument                 │
│      (nu apare în process list)                                  │
│                                                                  │
│  🔒  PREVENIRE SHELL INJECTION                                   │
│      Variabilele se trec prin sys.argv[], nu prin                │
│      interpolare de string-uri în shell                          │
│                                                                  │
│  🔒  PAROLA WIFI SECURIZATĂ                                      │
│      Nu apare în /proc/*/cmdline                                 │
│                                                                  │
│  🔒  DETECȚIE VM                                                  │
│      CPU stress test sărit în mașini virtuale                    │
│      (previne RCU stall — kernel panic în VM)                    │
│                                                                  │
│  🔒  TRAP ERR → RECOVERY SHELL                                   │
│      Dacă un script crash-uiește, utilizatorul                   │



# RedSeek Rescue — Analiză Tehnică

**Generat de:** DeepSeek Flash (analiză tehnică)
**Refinat de:** Opus (prezentare profesională)
**Data:** 14 Iulie 2026
**Repo:** [github.com/rednicv/redseek-rescue](https://github.com/rednicv/redseek-rescue)
**Versiune curentă:** 1.8.0

---

## 1. Build & Deployment

### 1.1. Construirea ISO-ului

Procesul de build se realizează printr-un singur script — `build.sh` — care orchestrează întreaga construcție folosind **live-build** pe baza Ubuntu Noble (24.04 LTS).

| Parametru | Valoare |
|---|---|
| **Script de build** | `build.sh` |
| **Dimensiune ISO** | ~3.1 GB |
| **Arhitectură** | doar `amd64` |
| **Compresie** | SquashFS (~2.9 GB după compresie) |
| **Boot** | BIOS (MBR) + UEFI (El Torito) |
| **Dependențe build** | `live-build`, `syslinux-utils`, `python3-yaml`, `git` |

### 1.2. Publicare & Distribuție

ISO-ul este publicat prin **GitHub Releases**, împărțit în părți de maximum 2 GB (limita GitHub per artefact). Scrierea pe USB se face cu:

- **Rufus** (Windows) — în modul **DD Image**
- **`dd`** (Linux/macOS) — scriere directă pe dispozitiv

### 1.3. CI/CD

Proiectul utilizează **GitHub Actions** cu două workflow-uri:

| Workflow | Scop |
|---|---|
| `workflows/build-iso.yml` | Construirea ISO-ului |
| `workflows/ci.yml` | Rularea testelor automate |

Testarea se realizează prin **BATS** (Bash Automated Testing System):
- `tests/scripts.bats` — validare scripturi de reparare
- `tests/utils.bats` — validare utilități partajate

### 1.4. Istoric Versiuni

| Versiune | Descriere |
|---|---|
| `v1.4.x` | Versiunea inițială |
| `v1.6.x` | Refactorizare majoră (Opus/Gemini) |
| `v1.8.0` | Versiunea curentă stabilă |

---

## 2. Pros & Cons

### ✅ Puncte Tari

| # | Aspect | Detalii |
|---|---|---|
| 1 | **Funcționare duală AI + Offline** | Agentul AI (Hermes + DeepSeek) oferă ghidare inteligentă când este disponibilă o conexiune și o cheie API, dar toate cele 18 scripturi de reparare funcționează complet offline, fără nicio dependență de servicii externe. |
| 2 | **Backup automat pre-modificare** | Înainte de orice operație care alterează date pe partiția Windows, sistemul creează automat un punct de restaurare. Reduce riscul de pierderi de date la minimum. |
| 3 | **Gestionare NTFS case-insensitive** | Scripturile tratează corect sistemul de fișiere NTFS, care este case-insensitive — o problemă frecvent ignorată de alte tool-uri Linux de reparare Windows. |
| 4 | **Suport BitLocker** | Partițiile criptate cu BitLocker sunt recunoscute și gestionate, permițând accesul la date atunci când utilizatorul deține cheia de recuperare. |
| 5 | **Acces SSH inclus** | Permite diagnosticarea și repararea de la distanță, util în scenarii de suport tehnic remote. |

### ❌ Puncte Slabe

| # | Aspect | Detalii |
|---|---|---|
| 1 | **Build exclusiv amd64** | ISO-ul nu poate fi construit pe arhitecturi ARM (cross-compilation nesuportată). Limitat la mașini x86_64. |
| 2 | **AI necesită internet** | Componenta de asistență AI depinde de conectivitate și de API-ul DeepSeek. Fără internet, utilizatorul rămâne cu modul manual. |
| 3 | **Dimensiune ISO considerabilă** | La ~3.1 GB, ISO-ul necesită timp de descărcare semnificativ și un stick USB de minim 4 GB. |
| 4 | **Lipsă testare automată a ISO-ului în CI** | Deși scripturile individuale sunt testate prin BATS, pipeline-ul CI nu validează ISO-ul rezultat (boot, integritate, funcționalitate end-to-end). |

---

## 3. Concluzie

RedSeek Rescue ocupă o nișă pe care puține proiecte o adresează cu aceeași coerență: **repararea instalațiilor Windows dintr-un mediu Linux live, cu asistență AI opțională**. Arhitectura este pragmatică — un Ubuntu LTS solid ca fundație, 18 scripturi Bash specializate care acoperă lanțul complet de la diagnosticare la recuperare, și un agent AI care transformă terminalul într-o conversație ghidată. Faptul că întregul sistem funcționează și fără AI, complet offline, demonstrează că inteligența artificială este tratată ca un accelerator, nu ca o dependență critică.

Deciziile de engineering reflectă o orientare clară spre siguranța datelor: backup-ul automat pre-modificare, gestionarea corectă a particularităților NTFS, și suportul BitLocker arată că proiectul a fost construit de cineva care a reparat suficiente sisteme Windows pentru a cunoaște exact ce poate merge prost. Adăugarea SSH-ului deschide ușa către un scenariu de suport tehnic remote complet funcțional — un tehnician poate asista un utilizator non-tehnic fără a fi prezent fizic.

Principalele direcții de îmbunătățire rămân dimensiunea ISO-ului (care ar putea beneficia de o variantă „lite" fără pachetele AI), extinderea CI-ului cu teste de integrare pe ISO-ul generat, și — pe termen lung — suport multi-arhitectură. Cu toate acestea, în forma sa actuală (v1.8.0), RedSeek Rescue este un instrument matur, bine structurat și gata de utilizare în producție, care rezolvă o problemă reală cu o abordare modernă.