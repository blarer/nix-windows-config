#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# WSL-side bootstrap for nix-windows-config.
#
# Run this INSIDE the Ubuntu distro, as your normal user:
#
#     bash windows/wsl-bootstrap.sh
#
# It is idempotent: re-running skips whatever is already in place.
#
# What it does, in order:
#   1. checks systemd is enabled (WSL needs [boot] systemd=true)
#   2. installs Determinate Nix, if absent
#   3. registers a systemd unit for the Nix daemon (the installer's
#      --init none path skips this)
#   4. clones this repo to ~/nix-windows-config, if absent
#   5. warns about a ~/.gitconfig that would shadow the managed config
#   6. activates the home-manager generation
#   7. sets zsh as the login shell
#   8. runs the smoke test
#
# Deliberately ASCII-only: this file gets copied across the Windows/WSL
# boundary by tools that are careless with encodings, and box-drawing
# characters do not survive that reliably.
# ---------------------------------------------------------------------------
set -euo pipefail

REPO_URL="https://github.com/blarer/nix-windows-config.git"
REPO_DIR="$HOME/nix-windows-config"
NIX_BIN="/nix/var/nix/profiles/default/bin"

step() { printf '\n==> %s\n' "$1"; }
skip() { printf '    - %s\n' "$1"; }
ok()   { printf '    + %s\n' "$1"; }

# --- 1. systemd ------------------------------------------------------------
step 'Checking systemd'
if ! systemctl is-system-running 2>/dev/null | grep -qE 'running|degraded|starting'; then
  cat >&2 <<'EOF'
systemd is not running in this distro. Add the following to /etc/wsl.conf:

    [boot]
    systemd=true

then run `wsl --shutdown` from Windows and start Ubuntu again.
EOF
  exit 1
fi
ok 'systemd is running'

# --- 2. Nix ----------------------------------------------------------------
step 'Installing Determinate Nix'
if [ -x "$NIX_BIN/nix" ]; then
  skip "nix already present ($("$NIX_BIN/nix" --version))"
else
  sudo apt-get update -qq
  sudo apt-get install -y -qq curl xz-utils ca-certificates
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    -o /tmp/nix-install.sh
  sudo sh /tmp/nix-install.sh install linux --no-confirm --init none
  ok 'nix installed'
fi

export PATH="$NIX_BIN:$PATH"
export NIX_CONFIG="experimental-features = nix-command flakes"

# --- 3. Daemon unit --------------------------------------------------------
# Installed with --init none because WSL brings systemd up on its own
# schedule, so we register the unit ourselves.
#
# Type=simple, not Type=notify: determinate-nixd never sends an sd_notify
# readiness signal, so Type=notify makes systemd block until it times out
# even though the socket is created and usable within a second.
step 'Registering nix-daemon systemd unit'
if systemctl is-active --quiet nix-daemon.service; then
  skip 'nix-daemon already active'
else
  sudo tee /etc/systemd/system/nix-daemon.service >/dev/null <<'UNIT'
[Unit]
Description=Determinate Nix Daemon
Documentation=https://docs.determinate.systems/
RequiresMountsFor=/nix/store
ConditionPathIsReadWrite=/nix/var/nix

[Service]
Type=simple
ExecStart=/usr/local/bin/determinate-nixd --nix-bin /nix/var/nix/profiles/default/bin daemon
KillMode=process
LimitNOFILE=1048576
TasksMax=1048576
Restart=on-failure
RestartSec=1

[Install]
WantedBy=multi-user.target
UNIT
  sudo systemctl daemon-reload
  sudo systemctl enable --now nix-daemon.service
  sleep 2
  ok "nix-daemon: $(systemctl is-active nix-daemon.service)"
fi

# --- 4. Repo ---------------------------------------------------------------
step 'Fetching the config'
if [ -d "$REPO_DIR/.git" ]; then
  skip "$REPO_DIR already exists"
else
  git clone "$REPO_URL" "$REPO_DIR"
  ok "cloned to $REPO_DIR"
fi
cd "$REPO_DIR"

# --- 5. Shadowing gitconfig ------------------------------------------------
# Git reads ~/.gitconfig before ~/.config/git/config, so if one exists the
# entire home-manager git configuration is inert. `git config --global`
# creates it, which makes this very easy to hit by accident.
step 'Checking for a shadowing ~/.gitconfig'
if [ -f "$HOME/.gitconfig" ]; then
  echo "    ! ~/.gitconfig exists and overrides the managed git config."
  echo "      Contents:"
  sed 's/^/        /' "$HOME/.gitconfig"
  echo "      Move it aside with: mv ~/.gitconfig ~/.gitconfig.bak"
else
  ok 'no shadowing ~/.gitconfig'
fi

# --- 6. Activate -----------------------------------------------------------
step 'Activating home-manager generation'
nix run home-manager/master -- switch --flake ".#wsl" -b hm-backup

# --- 7. Login shell --------------------------------------------------------
# Home Manager configures zsh and writes ~/.zshenv, but it cannot change the
# login shell in /etc/passwd. Without this you land in bash and none of that
# configuration loads.
step 'Setting zsh as the login shell'
ZSH_BIN="$HOME/.nix-profile/bin/zsh"
CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7)"
if [ "$CURRENT_SHELL" = "$ZSH_BIN" ]; then
  skip "login shell already $ZSH_BIN"
elif [ ! -x "$ZSH_BIN" ]; then
  echo "    ! $ZSH_BIN not found; skipping"
else
  # chsh refuses any shell that is not listed in /etc/shells.
  if ! grep -qxF "$ZSH_BIN" /etc/shells 2>/dev/null; then
    echo "$ZSH_BIN" | sudo tee -a /etc/shells >/dev/null
  fi
  sudo chsh -s "$ZSH_BIN" "$USER"
  ok "login shell set to $ZSH_BIN (applies to new sessions)"
fi

# --- 8. Verify -------------------------------------------------------------
step 'Running smoke test'
zsh windows/smoketest.zsh || true

cat <<'EOF'

Done. Open a new shell (or run `exec zsh`) to pick up the environment.

Day-to-day from here:
    just switch        # build + diff + confirm
    just switch-fast   # build + activate
    just check         # fmt-check + lint + deadnix + flake check
    just smoke         # re-run this smoke test
EOF
