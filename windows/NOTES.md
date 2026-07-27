# Windows port notes

macOS-only items dropped (no viable Windows equivalent):

| Dropped | Why | Windows alternative |
|---|---|---|
| osaurus | macOS-only local LLM runner | Ollama (winget) |
| orion, helium-browser | macOS-only browsers | Brave / Zen (installed) |
| sol | macOS Spotlight replacement | PowerToys Run (installed, on Alt+Space) |
| little-snitch | macOS app firewall | simplewall / GlassWire (manual) |
| sentinel | macOS persistence manager | Autoruns (Sysinternals, manual) |
| metasploit | no stable winget entry | Run via WSL2 Kali or install manually |
| onyx, pearcleaner | macOS cleaners | BCUninstaller (manual) |
| keyclu | macOS shortcut cheatsheet | PowerToys ShortcutGuide |
| keka | macOS archiver | 7-Zip (scoop, already covered) |
| coteditor | macOS text editor | Notepad++ or VSCodium |
| tradingview | inconsistent winget id | Install from vendor site |
| orbstack | macOS container runner | Docker Desktop (installed) OR use WSL2 directly |
| iina | macOS video player | mpv (scoop) |
| stats | macOS menu bar monitor | Task Manager / btop in WSL |
| Xcode | macOS SDK | N/A |
| Windows App (MAS) | already native on Windows | built-in Remote Desktop |
| Touch ID sudo | macOS PAM | Windows Hello + gsudo (limited parity) |

All CLI tooling (ripgrep, fd, bat, eza, fzf, zoxide, atuin, starship, delta,
difftastic, gh, helix, uv, ruff, nixd, just, tokei, hyperfine, jq, yq, nmap,
masscan, nikto, wireguard, claude-code, opencode, etc.) lives inside WSL2 via
the Nix flake — identical versions to macOS. Do NOT reinstall these natively.

## Terminal history

The port originally shipped a WezTerm lua config. It was replaced by
**Alacritty**, whose config lives at `windows/alacritty/alacritty.toml` and is
deployed to `%APPDATA%\alacritty\alacritty.toml`.

The "Fluent Dark" palette, FiraCode Nerd Font setup, and CTRL+SHIFT keybinding
convention carried over 1:1. What did not carry over, because Alacritty has no
such concepts by design: tabs, splits/panes, the lua status bar, workspaces,
and the leader-key tables. Use GlazeWM (`alt+hjkl`) for window splitting, or a
multiplexer inside the shell.

## Window manager history

The first cut of this port used **komorebi + whkd**. It was replaced by
**GlazeWM**, which tiles and handles its own hotkeys in a single process with
one YAML config, removing the separate hotkey daemon. The komorebi configs
(`komorebi.json`, `komorebi.bar.json`, `whkdrc`) were removed in the switch and
remain in git history if ever needed.

Do not run komorebi and GlazeWM at the same time: both hook window placement
and will fight each other. `smoketest-windows.ps1` fails if komorebi or whkd is
found running.
