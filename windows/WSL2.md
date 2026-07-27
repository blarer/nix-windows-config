# WSL2 + home-manager standalone

Goal: run the `modules/` from this flake inside WSL2 Ubuntu so the shell, CLI
tools, editor, and dev env match macOS 1:1. Window management, fonts, and
GUI apps stay on the Windows host (see `bootstrap.ps1`).

## Fast path

```powershell
wsl --install -d Ubuntu       # from Windows, admin; reboot if prompted
```

Then, inside Ubuntu, one command does everything:

```bash
bash /mnt/c/Users/blare/nix-windows-config/windows/wsl-bootstrap.sh
```

It installs Determinate Nix, registers the `nix-daemon` systemd unit, clones
this repo to `~/nix-windows-config`, activates the home-manager generation, and
runs the smoke test. It is idempotent, so re-running is safe.

The rest of this document explains what that script does and how to do it by
hand.

## Prerequisite: systemd

WSL needs systemd for the Nix daemon to be supervised. Check `/etc/wsl.conf`:

```ini
[boot]
systemd=true

[user]
default=blare
```

After editing, run `wsl --shutdown` from Windows and reopen the distro. The
username must match `primary_username` in `flake.nix`.

## Manual steps

The flake already ships a `homeConfigurations.wsl` output and a Linux-filtered
`packages.nix`, so there is nothing to hand-edit.

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

### If the daemon does not start

On WSL the installer can finish without a working daemon (`error: cannot
connect to socket at '/nix/var/nix/daemon-socket/socket'`), because systemd
comes up on WSL's own schedule. Register the unit yourself:

```bash
sudo tee /etc/systemd/system/nix-daemon.service >/dev/null <<'UNIT'
[Unit]
Description=Determinate Nix Daemon
RequiresMountsFor=/nix/store
ConditionPathIsReadWrite=/nix/var/nix

[Service]
Type=simple
ExecStart=/usr/local/bin/determinate-nixd --nix-bin /nix/var/nix/profiles/default/bin daemon
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl daemon-reload
sudo systemctl enable --now nix-daemon.service
```

`Type=simple` is deliberate: `determinate-nixd` never sends an `sd_notify`
readiness signal, so `Type=notify` makes systemd wait until it times out even
though the socket works within a second.

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
