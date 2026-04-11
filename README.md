# nix-windows-config

Windows (WSL2 + home-manager) counterpart to `nix-darwin-config`. Hybrid setup:

- **WSL2 Ubuntu + home-manager standalone** — shell, CLI tools, editor, dev env reused 1:1 from the Darwin modules (filtered to drop macOS-only deps).
- **Windows host** — WezTerm, komorebi (tiling WM) + whkd (hotkeys), GUI apps via winget/scoop.

## Layout

| Path | Purpose |
|---|---|
| `flake.nix` | Standalone home-manager flake (`homeConfigurations.wsl`) |
| `packages.nix` | Linux-filtered package set |
| `modules/home.nix` | Home-manager module (zsh, starship, helix, git, gh, delta, etc.) |
| `windows/bootstrap.ps1` | One-shot Windows installer (winget + scoop + configs + WSL2) |
| `windows/winget.json` | GUI apps |
| `windows/komorebi.json` | Tiling WM config |
| `windows/whkdrc` | Hotkey daemon rules |
| `windows/wezterm/wezterm.lua` | WezTerm terminal config |

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
