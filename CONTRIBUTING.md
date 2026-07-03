# Contributing to RedSeek Rescue

Thanks for wanting to help! Here's how.

## Ways to Contribute

- **Report bugs** — open an Issue
- **Suggest features** — open an Issue with the `enhancement` label
- **Add rescue scripts** — see `scripts/` directory for the pattern
- **Improve documentation** — README, INSTALL, or this file
- **Test on real hardware** — boot the ISO on different PCs and report results

## Adding a New Rescue Script

1. Create `scripts/your-tool.sh`
2. Make it self-documenting (run without args → show usage)
3. Add it to `config/rescue-prompt.txt` under the right category
4. Add required packages to the list in `build.sh`
5. Test that it runs from the live USB environment
6. Open a PR

## Pull Request Process

1. Fork the repo
2. Create a branch: `feature/your-feature` or `fix/your-fix`
3. Make your changes
4. Test (at minimum: `bash -n build.sh`)
5. Open a PR against `main`
6. Describe what you changed and why

## Code Style

- **Shell scripts:** `#!/usr/bin/env bash`, `set -euo pipefail`
- **Comments:** Explain *why*, not *what*
- **Naming:** lowercase, hyphens for spaces (`mount-windows.sh`, not `MountWindows.sh`)

## Questions?

Open an Issue — happy to help.

---

**by [rednic](https://github.com/rednicv)**
