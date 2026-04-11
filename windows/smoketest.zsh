#!/usr/bin/env zsh
# Comprehensive smoke test for nix-windows-config home-manager generation.
# Run with:  zsh ~/nix-windows-config/windows/smoketest.zsh

emulate -L zsh
setopt extended_glob

red()   { print -P "%F{red}$1%f"   }
green() { print -P "%F{green}$1%f" }
yellow(){ print -P "%F{yellow}$1%f"}

heading() { print; print -P "%B%F{cyan}== $1 ==%f%b" }

heading "Shell"
print "ZSH_VERSION=$ZSH_VERSION"
print "SHELL=$SHELL"
print "User shell: $(getent passwd $USER | cut -d: -f7)"

heading "Environment variables"
for v in EDITOR VISUAL LANG PAGER MANPAGER LESS BAT_THEME CLICOLOR \
         PYTHONDONTWRITEBYTECODE DFT_BACKGROUND DFT_DISPLAY GCC_COLORS; do
  printf "  %-25s = %s\n" "$v" "${(P)v:-<unset>}"
done

heading "Binaries (~/.nix-profile/bin)"
local bins=(zsh starship rg fd bat eza hx gh delta difft nixd nixfmt ruff taplo \
            just nmap masscan nikto arp-scan nvd jq yq atuin zoxide fzf direnv \
            btop tldr node)
for b in $bins; do
  if command -v $b >/dev/null 2>&1; then
    green "  ✓ $b"
  else
    red   "  ✗ $b MISSING"
  fi
done

heading "Shell functions"
local fns=(dev nixconf gwt mark jump extract nix-init nix-search nix-info \
           nix-which nix-tmp net-discover port-scan vuln-scan fast-scan \
           web-scan vpn-home)
for f in $fns; do
  if (( $+functions[$f] )); then
    green "  ✓ $f"
  else
    red   "  ✗ $f MISSING"
  fi
done

heading "Aliases"
local als=(g gs gd gds ga gc gp gl gco gb find grep cat less ps du df top \
           lsg llg tl ping curl dig ports pubip)
for a in $als; do
  if alias $a >/dev/null 2>&1; then
    green "  ✓ $a → $(alias $a | cut -d= -f2-)"
  else
    red   "  ✗ $a MISSING"
  fi
done

heading "Git config"
local gcfg=(
  "user.name"
  "user.email"
  "init.defaultBranch"
  "rebase.autoSquash"
  "rebase.autoStash"
  "rebase.updateRefs"
  "fetch.fsckobjects"
  "transfer.fsckobjects"
  "core.fsmonitor"
  "core.untrackedCache"
  "core.commitGraph"
  "merge.conflictstyle"
  "branch.autosetuprebase"
  "log.date"
  "help.autocorrect"
  "diff.tool"
)
for k in $gcfg; do
  local val=$(git config --global --get $k 2>/dev/null)
  if [[ -n "$val" ]]; then
    green "  ✓ $k = $val"
  else
    red   "  ✗ $k UNSET"
  fi
done

heading "Git aliases"
local glas=(s co cb cm lg lga prettylog cleanup root amend fixup wip undo \
            stash-all unstash sync difft)
for ga in $glas; do
  if git config --global --get alias.$ga >/dev/null 2>&1; then
    green "  ✓ $ga"
  else
    red   "  ✗ $ga MISSING"
  fi
done

heading "Helix LSPs"
hx --health 2>/dev/null | command grep -E "(nixd|ruff|taplo|nixfmt)" | head -10

heading "Versions"
print "  zsh:       $ZSH_VERSION"
print "  starship:  $(starship --version | head -1)"
print "  helix:     $(hx --version | head -1)"
print "  ripgrep:   $(rg --version | head -1)"
print "  nixd:      $(nixd --version 2>/dev/null | head -1)"
print "  atuin:     $(atuin --version)"

heading "systemd timer"
systemctl --user list-timers nix-gc.timer --no-pager 2>&1 | head -3

heading "Flake remote"
cd ~/nix-windows-config 2>/dev/null && {
  print "  origin: $(git config --get remote.origin.url)"
  print "  HEAD:   $(git rev-parse --short HEAD) ($(git log -1 --pretty=%s))"
}

print
green "Done."
