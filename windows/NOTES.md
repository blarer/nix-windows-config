# Windows port notes

macOS-only items dropped (no viable Windows equivalent):

| Dropped | Why | Windows alternative |
|---|---|---|
| osaurus | macOS-only local LLM runner | Ollama (winget) |
| orion, helium-browser | macOS-only browsers | Brave / Zen (installed) |
| sol | macOS Spotlight replacement | PowerToys Run (installed) |
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
