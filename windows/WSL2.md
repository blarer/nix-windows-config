# WSL2 + home-manager standalone

Goal: run the `modules/` from this flake inside WSL2 Ubuntu so the shell, CLI
tools, editor, and dev env match macOS 1:1. Window management, fonts, and
GUI apps stay on the Windows host (see `bootstrap.ps1`).

## 0. Prereqs (from Windows PowerShell, admin)

```powershell
wsl --install -d Ubuntu
# reboot if prompted, then finish Ubuntu first-run to create your user
```

## 1. Install Nix (Determinate installer — matches macOS setup)

Inside the Ubuntu shell:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
exec $SHELL
```

## 2. Clone the config

```bash
git clone https://github.com/blarer/nix-darwin-config.git ~/nix-darwin-config
cd ~/nix-darwin-config
```

## 3. Add a `homeConfigurations.wsl` output

Edit `flake.nix`. Inside the `outputs = { self, ... }@inputs: let ... in { ... }`
block, add a sibling to `darwinConfigurations`:

```nix
homeConfigurations."wsl" = inputs.home-manager.lib.homeManagerConfiguration {
  pkgs = import inputs.nixpkgs {
    system = "x86_64-linux";         # or aarch64-linux on ARM hosts
    config.allowUnfree = true;
    overlays = overlays;
  };
  extraSpecialArgs = {
    inherit inputs git_user_name git_user_email shared_env;
    primary_username = "YOUR_WSL_USERNAME";
    package_sets = import ./packages.nix {
      pkgs = import inputs.nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; inherit overlays; };
    };
  };
  modules = [
    {
      home.username      = "YOUR_WSL_USERNAME";
      home.homeDirectory = "/home/YOUR_WSL_USERNAME";
      home.stateVersion  = "24.11";
    }
    ./modules/shell.nix
    ./modules/development.nix
    # Skip: modules/aerospace.nix      (macOS tiling WM — replaced by komorebi on Windows host)
    # Skip: modules/wezterm            (WezTerm runs on the Windows host, not in WSL)
    # Skip: modules/secrets.nix        (agenix-hm optional — see §5)
  ];
};
```

## 4. Filter macOS-only packages from `packages.nix`

Some entries only exist / only make sense on Darwin. Guard them before the
WSL build:

```nix
# In packages.nix — at top of the user_apps list:
user_apps = with pkgs; [
  # Darwin-only (skip on Linux):
  # iina            — macOS media player
  # stats           — macOS menu bar monitor
  # cyberduck       — provided as brew cask in nixpkgs, macOS-only
  # wezterm         — runs on Windows host, not inside WSL
] ++ lib.optionals pkgs.stdenv.isLinux [
  mpv                       # iina replacement
] ++ lib.optionals pkgs.stdenv.isDarwin [
  iina stats cyberduck wezterm brave
];
```

Quickest path: duplicate `packages.nix` → `packages-linux.nix` without the
macOS-only entries, and import that one from the WSL homeConfiguration.

Darwin-only items that must go: `iina`, `stats`, `cyberduck`, `wezterm`,
`brave` (linux build may work but you already have Brave on the Windows host),
`ifuse` (needs macFUSE; use `libimobiledevice` alone on Linux), `libimobiledevice`
works, `wimlib` works, `ntfs3g` works, `_7zz` works.

## 5. Build and activate

```bash
nix run home-manager/master -- switch --flake ~/nix-darwin-config#wsl
```

First build is slow (compiles a lot). Subsequent builds hit the cache.

## 6. Optional: agenix secrets in WSL

If you want `secrets/*.age` decrypted in WSL, install `agenix` as a
home-manager module. Easiest: use
[agenix-rekey](https://github.com/oddlama/agenix-rekey) or just copy
`~/.config/sops/age/keys.txt` from your mac. The existing `modules/secrets.nix`
targets nix-darwin — port the paths from `/run/agenix/` to
`${config.home.homeDirectory}/.agenix/` for HM.

Skip this for the first pass; bootstrap the shell/dev env first, layer
secrets later.

## 7. Interop tips

- **Run Windows binaries from WSL:** `wezterm.exe`, `code.exe`, `explorer.exe .`
- **Launch wezterm pointing at WSL:** set
  `config.default_prog = { "wsl.exe", "~", "-d", "Ubuntu" }` in
  `windows/wezterm/wezterm.lua`.
- **Atuin sync across host + WSL:** use the same server + key; the atuin
  daemon in `modules/shell.nix` runs fine inside WSL.
- **clipboard:** WSL2 auto-bridges `clip.exe` / PowerShell `Get-Clipboard`.
  Add `alias pbcopy=clip.exe` in a linux-only conditional if you want macOS
  parity.

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
| WezTerm | Windows host, Windows-native config |
| Tiling WM | komorebi + whkd on Windows host |
| Fonts (FiraCode NF) | Windows host via scoop nerd-fonts bucket |
