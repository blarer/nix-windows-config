# Justfile — common operations for nix-windows-config (WSL2 + home-manager)
# Run `just` to see available commands

config_dir := env_var('HOME') + "/nix-windows-config"

default:
    @just --list

# ─────────────────────────────────────────────────────────────
# Core Operations
# ─────────────────────────────────────────────────────────────

# Build + activate the wsl home-manager generation (with diff)
switch:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Building..."
    nix run home-manager/master -- build --flake {{config_dir}}#wsl
    echo ""
    echo "Diff:"
    nvd diff ~/.local/state/nix/profiles/home-manager result || true
    echo ""
    read -p "Apply? [y/N] " -n 1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        nix run home-manager/master -- switch --flake {{config_dir}}#wsl -b hm-backup
    fi

# Quick switch (no diff prompt)
switch-fast:
    nix run home-manager/master -- switch --flake {{config_dir}}#wsl -b hm-backup

# Build only
build:
    nix run home-manager/master -- build --flake {{config_dir}}#wsl

# Build without activating, to see what would change
dry-run:
    nix run home-manager/master -- build --flake {{config_dir}}#wsl
    nvd diff ~/.local/state/nix/profiles/home-manager result

# ─────────────────────────────────────────────────────────────
# Verification
# ─────────────────────────────────────────────────────────────

# WSL-side smoke test of the activated generation
smoke:
    zsh {{config_dir}}/windows/smoketest.zsh

# Windows-side checks that need no Nix (run these from PowerShell on the host):
#   powershell -NoProfile -File tools\check-nix-syntax.ps1
#   powershell -NoProfile -File tools\check-readme.ps1
#   powershell -NoProfile -File windows\smoketest-windows.ps1

# Everything that can be checked without activating
check: fmt-check lint deadnix check-flake
    @echo "All checks passed."

# ─────────────────────────────────────────────────────────────
# Updates
# ─────────────────────────────────────────────────────────────

update: update-lock switch
update-lock:
    nix flake update --flake {{config_dir}}
update-input INPUT:
    nix flake lock --update-input {{INPUT}} --flake {{config_dir}}
update-nixpkgs:
    just update-input nixpkgs

# ─────────────────────────────────────────────────────────────
# Code Quality
# ─────────────────────────────────────────────────────────────

fmt:
    nix fmt {{config_dir}}
fmt-check:
    nix fmt {{config_dir}} -- --ci
lint:
    statix check {{config_dir}}
deadnix:
    deadnix {{config_dir}}
check-flake:
    nix flake check {{config_dir}}

# ─────────────────────────────────────────────────────────────
# Maintenance
# ─────────────────────────────────────────────────────────────

# GC: keep last 14 days
gc:
    nix-collect-garbage --delete-older-than 14d
    nix store optimise

# Aggressive GC
gc-all:
    nix-collect-garbage -d
    nix store optimise

store-size:
    du -sh /nix/store

generations:
    home-manager generations

rollback:
    home-manager generations | head -2 | tail -1 | awk '{print $NF}' | xargs -I{} {}/activate

# ─────────────────────────────────────────────────────────────
# Information
# ─────────────────────────────────────────────────────────────

info:
    nix flake info {{config_dir}}
show:
    nix flake show {{config_dir}}
repl:
    nix repl --expr 'builtins.getFlake "path:{{config_dir}}"'
packages:
    nix-store -q --references ~/.nix-profile | sort
search QUERY:
    nix search nixpkgs#{{QUERY}}
pkg-info PKG:
    nix eval nixpkgs#{{PKG}}.meta --json 2>/dev/null | jq '.' || echo "Package not found"

# ─────────────────────────────────────────────────────────────
# Quick Access
# ─────────────────────────────────────────────────────────────

edit:
    cd {{config_dir}} && $EDITOR .
edit-flake:
    $EDITOR {{config_dir}}/flake.nix
edit-home:
    $EDITOR {{config_dir}}/modules/home.nix

# ─────────────────────────────────────────────────────────────
# Health
# ─────────────────────────────────────────────────────────────

health:
    #!/usr/bin/env bash
    echo "Disk:"; df -h ~ | awk 'NR==2 {print "  "$5" used, "$4" free"}'
    echo "Nix store:"; du -sh /nix/store 2>/dev/null | awk '{print "  "$1}'
    echo "Generations:"; home-manager generations 2>/dev/null | wc -l | awk '{print "  "$1}'
