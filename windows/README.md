# Windows port — nix-darwin-config

Hybrid setup: **WSL2 + Nix** reuses `modules/` 1:1 for the shell, CLI tools,
editor, and dev env. **Windows host** runs WezTerm, komorebi (tiling WM),
whkd (hotkeys), and GUI apps installed via winget/scoop.

## Layout

| File | Purpose |
|---|---|
| `bootstrap.ps1` | One-shot installer: winget + scoop + configs + WSL2 |
| `winget.json` | `winget import`-compatible GUI app manifest |
| `scoop-packages.txt` | Fonts, komorebi, whkd, Windows-native fallbacks |
| `komorebi.json` | Tiling WM config (BSP, 5 workspaces, 0 gaps — matches aerospace) |
| `whkdrc` | Hotkeys ported from `modules/aerospace.nix` (Alt+hjkl etc) |
| `wezterm/wezterm.lua` | Windows-variant WezTerm config (CMD→CTRL+SHIFT) |
| `NOTES.md` | Which macOS apps were dropped and why |
| `WSL2.md` | How to run the flake as home-manager standalone inside WSL2 |

## Quick start

From an **elevated PowerShell 7** prompt in the repo root:

```powershell
cd windows
Set-ExecutionPolicy -Scope Process Bypass -Force
.\bootstrap.ps1
```

Then follow `WSL2.md` to bootstrap Nix + home-manager inside Ubuntu.

## Fidelity

| Capability | macOS | Windows port | Fidelity |
|---|---|---|---|
| zsh + starship + atuin + zoxide + direnv + fzf + bat | nix-darwin | WSL2 + Nix | 100% |
| Helix + LSPs (nixd/ruff/taplo) | nix-darwin | WSL2 + Nix | 100% |
| git + gh + delta + difftastic + aliases | nix-darwin | WSL2 + Nix | 100% |
| CLI replacements (rg, fd, eza, btop, dust, etc.) | nix-darwin | WSL2 + Nix | 100% |
| Pentest tools (nmap, masscan, nikto, wireguard) | nix-darwin | WSL2 + Nix | 100% |
| Python 3.14 free-threading + uv + pyright | nix-darwin | WSL2 + Nix | 100% |
| claude-code + opencode | nix-darwin | WSL2 + Nix | 100% |
| WezTerm | nix-darwin | Windows-native (port of lua config) | 95% |
| Tiling WM | AeroSpace | komorebi + whkd | 85% |
| GUI apps (Brave, Obsidian, Cursor, OBS, Burp, Spotify, …) | brew cask | winget | 80% (some dropped — see NOTES.md) |
| Fonts (FiraCode NF, Noto Emoji) | nixpkgs | scoop nerd-fonts | 100% |
| System defaults (dock/finder/keyboard) | `defaults write` | manual / PowerToys | ~40% |
| Touch ID sudo | PAM | gsudo + Windows Hello | partial |
| launchd services | darwin | Task Scheduler | partial |
| agenix secrets | nix-darwin | agenix in WSL (optional) | 90% |

**Estimated overall fidelity: ~90% of the daily dev loop, ~60% of the
system-integration niceties.** The dev experience (shell + editor + CLI +
Python/git workflow) is fully reproduced via WSL2 + the existing flake
modules. The things that don't port are macOS platform features
(Dock/Finder tweaks, Touch ID, MAS).
