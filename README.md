# nix-windows-config

Windows (WSL2 + home-manager) counterpart to `nix-darwin-config`. Hybrid setup:

- **WSL2 Ubuntu + home-manager standalone** — shell, CLI tools, editor, dev env reused 1:1 from the Darwin modules (filtered to drop macOS-only deps).
- **Windows host** — Alacritty, GlazeWM (tiling WM, built-in hotkeys), GUI apps via winget/scoop.

## Layout

| Path | Purpose |
|---|---|
| `flake.nix` | Standalone home-manager flake (`homeConfigurations.wsl`) |
| `packages.nix` | Linux-filtered package set |
| `treefmt.nix` | `nix fmt` config (nixfmt + taplo) |
| `modules/home.nix` | Home-manager module (zsh, starship, helix, git, gh, delta, etc.) |
| `modules/shell/functions/` | Autoloaded zsh function bodies (one file per function) |
| `tools/check-nix-syntax.ps1` | Structural check runnable on Windows, where `nix` is absent |
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

## Shell functions

Function bodies live one-per-file in `modules/shell/functions/` and are lazily
`autoload`ed from `~/.config/zsh/functions` (mirrors the Darwin config). To add
one: drop in a file whose contents are the body only (no `function name() { }`
wrapper), then add its name to the `autoload -Uz` list in `modules/home.nix`.

`tools/check-nix-syntax.ps1` enforces that both sides stay in sync, and that
the bodies keep LF endings (CRLF breaks them under zsh).

## Relationship to nix-darwin-config

The WSL side is a port of [`nix-darwin-config`](https://github.com/blarer/nix-darwin-config).
When pulling improvements across, note that upstream splits packages into
`packages/*.nix` and shell config into `modules/shell.nix`; this repo keeps a
single `packages.nix` and a single `modules/home.nix` because the Windows port
needs a much smaller subset. macOS-only functions (`ocvis`, `tor-toggle`,
`llm`) are deliberately not ported.
