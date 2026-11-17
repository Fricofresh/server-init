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
- Sudo user with SSH key auth
- SSH hardening (`sshd_config.d/99-init-hardening.conf`, root login disabled, backup at `sshd_config.bak`)
- **zsh + oh-my-zsh** with the custom `fricofresh` theme (`┌─[user@host]─[path]─[exit code]` two-line prompt)
- **lsd**, registered via `update-alternatives` so plain `ls` runs lsd (GNU `ls` kept as fallback at priority 40 — `update-alternatives --config ls` to switch back)
- fail2ban + unattended security upgrades
- Timezone
- NTP time sync (chrony installed only if the clock isn't already synchronized)

## Notes

- The oh-my-zsh installer runs as `$NEW_USER`; the default shell is set to zsh with `chsh`.
- If `$NEW_USER` already exists, the script only ensures keys/zsh/oh-my-zsh are in place — it skips `adduser`.
- Reboot recommended after first run.
