# nix-windows-config

Windows (WSL2 + home-manager) counterpart to `nix-darwin-config`. Hybrid setup:

- **WSL2 Ubuntu + home-manager standalone** — shell, CLI tools, editor, dev env reused 1:1 from the Darwin modules (filtered to drop macOS-only deps).
- **Windows host** — Alacritty, GlazeWM (tiling WM, built-in hotkeys), GUI apps via winget/scoop.

## Layout

| Path | Purpose |
|---|---|
| `flake.nix` | Standalone home-manager flake (`homeConfigurations.wsl`) |
| `packages.nix` | Linux-filtered package set |
| `modules/home.nix` | Home-manager module (zsh, starship, helix, git, gh, delta, etc.) |
| `windows/bootstrap.ps1` | One-shot Windows installer (winget + scoop + configs + WSL2) |
| `windows/winget.json` | GUI apps |
| `windows/glazewm/config.yaml` | Tiling WM + hotkey config (deployed to `~/.glzr/glazewm/`) |
| `windows/alacritty/alacritty.toml` | Terminal config (deployed to `%APPDATA%\alacritty\`) |
| `windows/smoketest-windows.ps1` | Verifies the Windows side; exits non-zero on failure |

## Activate WSL side

Inside Ubuntu WSL:

```bash
cd ~/nix-windows-config
nix run home-manager/master -- switch --flake .#wsl -b hm-backup
```

## Activate Windows side

From elevated PowerShell:

```powershell
cd C:\Users\blare\nix-windows-config\windows
Set-ExecutionPolicy -Scope Process Bypass -Force
.\bootstrap.ps1
```

Re-running is safe: every step is idempotent. Verify with:

```powershell
powershell -NoProfile -File windows\smoketest-windows.ps1
```

## Window manager

GlazeWM handles tiling and hotkeys (no separate hotkey daemon). The config is
tracked at `windows/glazewm/config.yaml` and deployed to
`~/.glzr/glazewm/config.yaml`. After editing, press `alt+shift+r` to reload,
then copy the file back into the repo so the smoketest's drift check stays
green.
