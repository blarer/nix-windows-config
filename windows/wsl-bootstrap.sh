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
#   1. installs Determinate Nix (if absent)
#   2. registers a systemd unit for the Nix daemon (the installer's
#      --init none path skips this, and WSL needs systemd=true anyway)
#   3. clones this repo to ~/nix-windows-config (if absent)
#   4. activates the home-manager generation
#   5. runs the smoke test
# ---------------------------------------------------------------------------
set -euo pipefail

REPO_URL="https://github.com/blarer/nix-windows-config.git"
REPO_DIR="$HOME/nix-windows-config"
NIX_BIN="/nix/var/nix/profiles/default/bin"

step() { printf '\n==> %s\n' "$1"; }
skip() { printf '    - %s\n' "$1"; }
ok()   { printf '    + %s\n' "$1"; }

# â”€â”€ 0. Sanity: systemd must be enabled for the daemon to be supervised â”€â”€â”€â”€â”€â”€
step 'Checking systemd'
if ! systemctl is-system-running >/dev/null 2>&1 && \
   ! systemctl is-system-running 2>/dev/null | grep -qE 'running|degraded'; then
  cat >&2 <<'EOF'
systemd is not running in this distro. Add the following to /etc/wsl.conf:

    [boot]
    systemd=true

then run `wsl --shutdown` from Windows and start Ubuntu again.
EOF
  exit 1
fi
ok 'systemd is running'

# â”€â”€ 1. Nix â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

# â”€â”€ 2. Daemon unit â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# The installer is run with --init none because WSL's systemd comes up after
# the installer's own checks; we register the unit ourselves.
#
# Type=simple, not Type=notify: determinate-nixd does not send an sd_notify
# readiness signal, so Type=notify makes systemd block until it times out even
# though the socket is created and usable within a second.
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

# â”€â”€ 3. Repo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
step 'Fetching the config'
if [ -d "$REPO_DIR/.git" ]; then
  skip "$REPO_DIR already exists"
else
  git clone "$REPO_URL" "$REPO_DIR"
  ok "cloned to $REPO_DIR"
fi
cd "$REPO_DIR"

# â”€â”€ 4. A stray ~/.gitconfig silently shadows the managed config â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# Git reads ~/.gitconfig before ~/.config/git/config, so if one exists the
# entire home-manager git configuration is inert. `git config --global`
# creates it, which makes this very easy to hit by accident.
step 'Checking for a shadowing ~/.gitconfig'
if [ -f "$HOME/.gitconfig" ]; then
  echo "    ! ~/.gitconfig exists and will override the managed git config."
  echo "      Contents:"
  sed 's/^/        /' "$HOME/.gitconfig"
  echo "      Move it aside with: mv ~/.gitconfig ~/.gitconfig.bak"
else
  ok 'no shadowing ~/.gitconfig'
fi

# â”€â”€ 5. Activate â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
step 'Activating home-manager generation'
nix run home-manager/master -- switch --flake ".#wsl" -b hm-backup

# â”€â”€ 6. Verify â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
