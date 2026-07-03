# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in RedSeek Rescue, **please do not open a public issue.**

Instead, report it privately:

- **Email:** rednic@ltos.ro
- **GitHub:** Open a private vulnerability report (coming soon)

We'll respond within 48 hours and work with you on a fix before public disclosure.

## Scope

The RedSeek Rescue ISO includes:

- A minimal Ubuntu Live environment
- Hermes Agent (AI assistant)
- Rescue scripts for Windows repair
- WiFi firmware from Ubuntu `restricted` repo

## What We Consider a Vulnerability

- Remote code execution via the rescue scripts or Hermes config
- Credential leakage (API keys saved in cleartext on the live system)
- Privilege escalation from `rescue` user to `root`
- Supply chain attacks via compromised build dependencies

## What We Do NOT Consider a Vulnerability

- The fact that API keys are stored in `/home/rescue/.hermes/config.yaml` on a **live USB** (this is ephemeral, no persistence between boots)
- Tools requiring root access (the entire live environment runs as root for repair purposes)
- Issues in third-party packages (report those to Ubuntu/Debian)

## Supported Versions

| Version | Status |
|---|---|
| 1.0.x   | ✅ Supported |

---

Thank you for keeping RedSeek Rescue safe.
