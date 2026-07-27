# WSL2 + home-manager standalone

Goal: run the `modules/` from this flake inside WSL2 Ubuntu so the shell, CLI
tools, editor, and dev env match macOS 1:1. Window management, fonts, and
GUI apps stay on the Windows host (see `bootstrap.ps1`).

The flake already ships a `homeConfigurations.wsl` output and a Linux-filtered
`packages.nix`, so there is nothing to hand-edit. Four commands total.

## 1. Install the distro (Windows PowerShell, admin)

```powershell
wsl --install -d Ubuntu
# reboot if prompted, then finish Ubuntu first-run to create your user
```

`bootstrap.ps1` does this for you if no distro is present.

## 2. Install Nix (Determinate installer — matches the macOS setup)

Inside the Ubuntu shell:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
exec $SHELL
```

## 3. Clone the config

```bash
git clone https://github.com/blarer/nix-windows-config.git ~/nix-windows-config
cd ~/nix-windows-config
```

The path matters: `Justfile` and the `dev`/`nixconf` shell functions all assume
`~/nix-windows-config`.

## 4. Build and activate

```bash
nix run home-manager/master -- switch --flake ~/nix-windows-config#wsl -b hm-backup
```

First build is slow (compiles a lot). Subsequent builds hit the cache. After
that, `just switch` (diff + confirm) or `just switch-fast` from the repo root.

If your WSL username is not `blare`, change `primary_username` in `flake.nix`
before the first switch.

## 5. Verify

```bash
zsh ~/nix-windows-config/windows/smoketest.zsh
```

Checks binaries, shell functions, aliases, git config, and Helix LSPs.
Expect zero red lines.

### Gotcha: `~/.gitconfig` shadows the Home Manager git config

Home Manager writes git settings to `~/.config/git/config`. Git reads
`~/.gitconfig` **first**, and if that file exists it wins, so every setting in
the smoketest's "Git config" section reports UNSET. This is easy to trigger by
accident, because `git config --global ...` creates `~/.gitconfig`.

```bash
rm ~/.gitconfig      # then re-run the smoketest
```

To add machine-local git settings without breaking the managed config, put
them in `~/.config/git/config.local` and include it, or set them per-repo.

## 6. Optional: agenix secrets in WSL

If you want `secrets/*.age` decrypted in WSL, install `agenix` as a
home-manager module. Easiest: use
[agenix-rekey](https://github.com/oddlama/agenix-rekey) or copy
`~/.config/sops/age/keys.txt` from your mac. The Darwin `modules/secrets.nix`
targets nix-darwin — port the paths from `/run/agenix/` to
`${config.home.homeDirectory}/.agenix/` for HM.

Skip this for the first pass; bootstrap the shell/dev env first, layer
secrets later.

## 7. Interop tips

- **Run Windows binaries from WSL:** `alacritty.exe`, `code.exe`, `explorer.exe .`
- **Point Alacritty at WSL:** uncomment the `wsl.exe` block in
  `windows/alacritty/alacritty.toml` (it defaults to `pwsh` so the terminal
  still works before the distro exists), then redeploy with `bootstrap.ps1`.
- **Atuin sync across host + WSL:** use the same server + key.
- **clipboard:** WSL2 auto-bridges `clip.exe` / PowerShell `Get-Clipboard`.
  Add `alias pbcopy=clip.exe` in `~/.zshrc.local` if you want macOS parity.
- **Keep the WM out of the way:** GlazeWM manages Windows-side windows only;
  it has no effect on anything inside WSL.

## What this gets you

| Area | Parity with macOS |
|---|---|
| zsh + starship + atuin + zoxide + direnv + fzf + bat | 100% |
| Helix + nixd/ruff/taplo LSPs | 100% |
| Git + gh + delta + difftastic | 100% |
| ripgrep/fd/eza/btop/dust/duf/sd/procs/xh/dog/gping | 100% |
| nmap/masscan/nikto/arp-scan/wireguard | 100% |
| uv + pyright + Python 3.14 free-threading | 100% |
| claude-code + opencode | 100% |
| agenix secrets | optional (step 6) |
| Terminal | Alacritty on the Windows host |
| Tiling WM | GlazeWM on the Windows host |
| Fonts (FiraCode NF) | Windows host via scoop nerd-fonts bucket |
