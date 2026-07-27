# Windows port — nix-windows-config

Hybrid setup: **WSL2 + Nix** reuses `modules/` 1:1 for the shell, CLI tools,
editor, and dev env. **Windows host** runs WezTerm, GlazeWM (tiling WM with
built-in hotkeys), and GUI apps installed via winget/scoop.

## Layout

| File | Purpose |
|---|---|
| `bootstrap.ps1` | One-shot, re-runnable installer: winget + scoop + configs + WSL2 |
| `winget.json` | `winget import`-compatible GUI app manifest |
| `scoop-packages.txt` | Fonts, glazewm, Windows-native fallbacks |
| `glazewm/config.yaml` | Tiling WM + hotkeys (Alt+hjkl etc), deployed to `~/.glzr/glazewm/` |
| `wezterm/wezterm.lua` | Windows-variant WezTerm config (CMD→CTRL+SHIFT) |
| `smoketest-windows.ps1` | Windows-side verification; exits non-zero on failure |
| `smoketest.zsh` | WSL-side verification of the home-manager generation |
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

## Window manager

GlazeWM replaced komorebi + whkd. It tiles *and* owns its hotkeys, so there is
no second daemon to configure. Key bindings (see `glazewm/config.yaml`):

| Binding | Action |
|---|---|
| `Alt+H/J/K/L` | Focus left/down/up/right |
| `Alt+Shift+H/J/K/L` | Move window |
| `Alt+1..9` | Switch workspace |
| `Alt+Shift+1..9` | Move window to workspace |
| `Alt+R` | Resize mode (then hjkl, escape to exit) |
| `Alt+V` | Toggle tiling direction |
| `Alt+F` / `Alt+M` | Fullscreen / minimize |
| `Alt+Shift+Space` | Toggle floating |
| `Alt+Enter` | Launch terminal |
| `Alt+Shift+Q` | Close window |
| `Alt+Shift+R` | Reload config |
| `Alt+Shift+E` | Exit GlazeWM |

`Alt+Space` is deliberately left free for PowerToys Run; cycle-focus is on
`Alt+G` instead.

GlazeWM autostarts via a `GlazeWM.lnk` shortcut in the Startup folder, which
`bootstrap.ps1` creates.

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
| Tiling WM | AeroSpace | GlazeWM | 90% |
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
