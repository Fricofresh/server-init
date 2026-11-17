# server-init

Bootstrap script for new Debian/Ubuntu servers. Run it as root right after first login:

```bash
sudo bash init.sh
```

User, SSH key URL and timezone are configured at the top of the script:

```bash
NEW_USER="fricofresh"
SSH_KEY_URL="https://github.com/Fricofresh.keys"
TIMEZONE="Europe/Berlin"
```

## What it sets up

- System update + base packages (curl, git, vim, htop, zsh, …)
- Sudo user with SSH key auth (no password set — run `passwd` after your first login; sudo needs it)
- **zsh + oh-my-zsh** with the custom `fricofresh` theme (`┌─[user@host]─[path]─[exit code]` two-line prompt)
- **lsd**, registered via `update-alternatives` so plain `ls` runs lsd (GNU `ls` kept as fallback at priority 40 — `update-alternatives --config ls` to switch back)
- fail2ban + unattended security upgrades
- Timezone
- NTP time sync (chrony installed only if the clock isn't already synchronized)
- A "run `passwd`" reminder banner appended to the new user's `~/.zshrc` (falls back to `~/.bashrc`) — remove it manually after setting your password (instructions are printed in the banner itself)

## Notes

- Fully non-interactive (safe to run from a VPS provider's init/cloud-init script): the user is created with `--disabled-password`, so the script never asks for a password.
- After the first SSH login, run `passwd` to set your own password — sudo requires it. Until then, `sudo` will prompt for a password that doesn't exist yet. The login banner reminds you of this until you remove it.
- If the SSH key URL is unreachable, the script warns and leaves password authentication enabled instead of risking a lockout.
- The oh-my-zsh installer runs as `$NEW_USER`; the default shell is set to zsh with `chsh`.
- If `$NEW_USER` already exists, the script only ensures keys/zsh/oh-my-zsh are in place — it skips `adduser`.
- `set -euo pipefail` is on: any failing step aborts the script with a clear exit code.
- Reboot recommended after first run. Keep your provider's console/recovery access as a safety net for the first login.
