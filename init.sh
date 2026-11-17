#!/usr/bin/env bash

# Made with help from AI
set -euo pipefail

NEW_USER="fricofresh"
SSH_KEY_URL="https://github.com/Fricofresh.keys"       # URL to a public key, or leave empty to skip
TIMEZONE="Europe/Berlin"                                 # e.g. "Europe/Berlin", or leave empty to skip

export DEBIAN_FRONTEND=noninteractive

echo "Updating system packages"
apt update
apt upgrade -y

echo "Installing base packages"
apt install -y \
  curl wget git vim htop zsh \
  fail2ban unattended-upgrades nala

# ---------------------------------------------------------------- new user ---
KEY_INSTALLED=0

if [[ -n "$NEW_USER" ]] && ! id "$NEW_USER" &>/dev/null; then
  echo "Creating user '$NEW_USER' with sudo access"
  adduser --gecos "" --disabled-password "$NEW_USER"
  usermod -aG sudo "$NEW_USER"
fi

if [[ -n "$NEW_USER" ]] && id "$NEW_USER" &>/dev/null; then
  install -d -m 700 -o "$NEW_USER" -g "$NEW_USER" "/home/$NEW_USER/.ssh"
  if [[ -n "$SSH_KEY_URL" ]]; then
    AUTH_KEYS="/home/$NEW_USER/.ssh/authorized_keys"
    if curl -fsSL --max-time 30 "$SSH_KEY_URL" -o "$AUTH_KEYS" && [[ -s "$AUTH_KEYS" ]]; then
      chown "$NEW_USER:$NEW_USER" "$AUTH_KEYS"
      chmod 600 "$AUTH_KEYS"
    else
      echo "WARNING: could not fetch SSH keys - password auth stays enabled"
      rm -f "$AUTH_KEYS"
    fi
  fi
  [[ -s "/home/$NEW_USER/.ssh/authorized_keys" ]] && KEY_INSTALLED=1
fi

# ------------------------------------------------------------------ zsh ---
if [[ -n "$NEW_USER" ]] && id "$NEW_USER" &>/dev/null && command -v zsh &>/dev/null; then
  USER_HOME=$(getent passwd "$NEW_USER" | cut -d: -f6)

  if [[ ! -d "$USER_HOME/.oh-my-zsh" ]]; then
    echo "Installing oh-my-zsh for $NEW_USER"
    su - "$NEW_USER" -c 'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"' </dev/null \
      || echo "WARNING: oh-my-zsh install failed - skipping"
  fi

  chsh -s "$(command -v zsh)" "$NEW_USER"

  if [[ -d "$USER_HOME/.oh-my-zsh/custom/themes" ]]; then
    echo "Installing fricofresh theme"
    cat > /tmp/fricofresh.zsh-theme <<'THEME'
# user, host, full path, and time/date
# on two lines for easier vgrepping
# entry in a nice long thread on the Arch Linux forums: https://bbs.archlinux.org/viewtopic.php?pid=521888#p521888
PROMPT=$'%{\e[0;34m%}%B┌─[%b%{\e[0m%}%{\e[1;32m%}%n%{\e[1;34m%}@%{\e[0m%}%{\e[0;36m%}%m%{\e[0;34m%}%B]%b%{\e[0m%}-%b%{\e[0;34m%}%B[%b%{\e[1;37m%}%~%{\e[0;34m%}%B]%b%{\e[0m%}-%{\e[0;34m%}%B[%b%{\e[0;33m%}%?%{\e[0;34m%}%B]%b%{\e[0m%}
%{\e[0;34m%}%B└─%B%{\e[1;35m%}$%{\e[0;34m%}%B%{\e[0m%}%b '
PS2=$'%{\e[0;34m%}%B>%{\e[0m%}%b '
THEME
    install -m 644 -o "$NEW_USER" -g "$NEW_USER" \
      /tmp/fricofresh.zsh-theme "$USER_HOME/.oh-my-zsh/custom/themes/fricofresh.zsh-theme"
    rm -f /tmp/fricofresh.zsh-theme
    sed -i 's/robbyrussell/fricofresh/g' "$USER_HOME/.zshrc"
  fi
fi

# ------------------------------------------------ password reminder banner ---
if [[ -n "$NEW_USER" ]] && id "$NEW_USER" &>/dev/null; then
  USER_HOME=$(getent passwd "$NEW_USER" | cut -d: -f6)
  RC_NAME=".zshrc"
  [[ -f "$USER_HOME/$RC_NAME" ]] || RC_NAME=".bashrc"

  if [[ -f "$USER_HOME/$RC_NAME" ]] && ! grep -q '### password reminder' "$USER_HOME/$RC_NAME"; then
    echo "Installing password reminder in ~$NEW_USER/$RC_NAME"
    cat >> "$USER_HOME/$RC_NAME" <<BANNER

### password reminder - delete this block once you have run 'passwd'
echo ""
echo ">>> NOTE: no password set yet - run 'passwd' to set one (needed for sudo)."
echo ">>> This reminder lives in ~/$RC_NAME."
echo ">>> To remove it: open that file and delete the lines between"
echo ">>> the two 'password reminder' marker lines (inclusive)."
### end password reminder
BANNER
  fi
fi

# ------------------------------------------------------------------ lsd ---
if LSD_VERSION=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/lsd-rs/lsd/releases/latest 2>/dev/null); then
  LSD_VERSION=${LSD_VERSION#v} # deb assets are named without the 'v' prefix, e.g. lsd_1.2.0_amd64.deb
  LSD_ARCH=$(dpkg --print-architecture)
  if curl -fsSL -o /tmp/lsd.deb \
    "https://github.com/lsd-rs/lsd/releases/download/${LSD_VERSION}/lsd_${LSD_VERSION}_${LSD_ARCH}.deb" \
    && nala install -y /tmp/lsd.deb; then
    rm -f /tmp/lsd.deb
  else
    rm -f /tmp/lsd.deb
    echo "WARNING: lsd download/install failed - 'ls' left as GNU ls"
  fi
else
  echo "WARNING: could not determine latest lsd version - skipping lsd install"
fi

if [[ -x /usr/bin/lsd ]]; then
  echo "Registering lsd as 'ls' via update-alternatives"
  if [[ -f /usr/bin/ls && ! -L /usr/bin/ls ]]; then
    mv /usr/bin/ls /usr/bin/ls.gnu
  fi
  update-alternatives --install /usr/bin/ls ls /usr/bin/ls.gnu 40 >/dev/null
  update-alternatives --install /usr/bin/ls ls /usr/bin/lsd 50 >/dev/null
else
  echo "WARNING: lsd binary missing - 'ls' left as GNU ls"
fi

# --------------------------------------------------------------- ssh harden ---
echo "Hardening sshd"
SSHD_CONF=/etc/ssh/sshd_config.d/99-init-hardening.conf
cp -n /etc/ssh/sshd_config /etc/ssh/sshd_config.bak 2>/dev/null || true
{
  echo "PermitRootLogin no"
  if [[ "$KEY_INSTALLED" -eq 1 ]]; then
    echo "PasswordAuthentication no"
  else
    echo "WARNING: no SSH key verified - password authentication stays enabled"
  fi
  echo "PubkeyAuthentication yes"
} > "$SSHD_CONF"

sshd -t || { echo "sshd config test failed - not restarting"; exit 1; }
systemctl restart ssh 2>/dev/null || systemctl restart sshd

# ------------------------------------------------------- unattended upgrades ---
echo "Enabling unattended security upgrades"
dpkg-reconfigure -f noninteractive unattended-upgrades

# ----------------------------------------------------------------- timezone ---
if [[ -n "$TIMEZONE" ]]; then
  echo "Setting timezone to $TIMEZONE"
  timedatectl set-timezone "$TIMEZONE"
fi

# --------------------------------------------------------------------- ntp ---
if [[ "$(timedatectl show -p NTPSynchronized --value 2>/dev/null)" != "yes" ]]; then
  echo "NTP not synchronized - installing and enabling chrony"
  nala install -y chrony
  systemctl enable --now chrony
fi

echo "Done. Log in as $NEW_USER and run 'passwd' to set your password (needed for sudo). Reboot recommended."
