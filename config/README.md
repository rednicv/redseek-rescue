# RedSeek Rescue AI — Configurare și Extensibilitate

Acest folder conține fișierele de configurare pentru **Hermes Agent**, motorul AI care rulează în RedSeek Rescue ISO. Aici poți modifica comportamentul asistentului AI, adăuga unelte (tools) noi sau schimba provider-ul LLM.

## Arhitectură

```
ISO boot → .profile detectează rețeaua
  ├─ Cu internet → hermes run rescue-prompt.txt
  │                  ├─ citește hermes-config.yaml
  │                  └─ AI-ul știe ce scripturi are la dispoziție
  └─ Fără internet → rescue-playbook.sh --offline
                       (playbook autonom, fără AI)
```

## Fișiere

### `rescue-prompt.txt`

Acesta este **prompt-ul de sistem** al AI-ului. Conține:

- Instrucțiuni de rol — „ești un expert în recuperare de date Windows"
- Lista scripturilor disponibile și ce face fiecare
- Flow-ul recomandat de acțiuni
- Restricții de securitate (ex: „nu formata fără confirmare")

**Cum modifici comportamentul AI-ului:** Editează acest fișier. Tot ce scrii aici devine „personalitatea" asistentului în ISO.

### `hermes-config.yaml`

Configurația provider-ului LLM pentru Hermes Agent:

```yaml
# Exemplu — înlocuiește cu cheia ta reală
provider: deepseek
model: deepseek-v4-flash
api_key: "sk-așternum..."
```

**La primul boot,** utilizatorul trebuie să adauge cheia API DeepSeek aici. Fără cheie, AI-ul nu poate porni → ISO comută automat în modul offline.

### `rescue-variables.sh`

Setări comune (mount points, căi implicite). Folosit de scripturile shell.

## Cum adaugi un tool nou pentru AI

1. Creează scriptul în `scripts/` (exemplu: `scripts/repair-boot.sh`)
2. Asigură-te că respectă pattern-ul: `source "${SCRIPT_DIR}/utils.sh"` + `require_root` + `find_ci`
3. Verifică sintaxa: `bash -n scripts/repair-boot.sh`
4. Verifică permisiunile: `chmod +x scripts/repair-boot.sh`
5. Adaugă descrierea tool-ului în `rescue-prompt.txt` la secțiunea „Available Tools"

AI-ul va descoperi automat noul tool și îl va folosi când e cazul.

## Cum schimbi provider-ul LLM

Poți folosi orice provider OpenAI-compatibil:

```yaml
# Exemplu: OpenAI
provider: openai
model: gpt-4o
api_key: "sk-..."
```

Sau orice alt model prin OpenRouter:

```yaml
provider: openrouter
model: anthropic/claude-sonnet-4
api_key: "sk-or-..."
```

## Debug

La boot, logurile Hermes sunt scrise în:
- `/tmp/hermes.log`
- `/tmp/redseek_offline_report.json` (dacă rulează în modul offline)
- `/opt/rescue/logs/*.log` (scripturile individuale)
