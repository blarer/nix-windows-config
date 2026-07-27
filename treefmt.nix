/*
  Code formatting configuration for the repository, managed by `treefmt-nix`.
  Enables `nix fmt` (and `just fmt` / `just fmt-check`).

  Usage:
  - `nix fmt`           Format all supported files.
  - `nix fmt -- --ci`   Check formatting without writing (used by `just check`).
*/
{ pkgs, ... }:
{
  projectRootFile = "flake.nix";

  programs = {
    # Nix formatting (RFC 166 compliant)
    nixfmt = {
      enable = true;
      package = pkgs.nixfmt;
    };

    # TOML — windows/alacritty/alacritty.toml
    taplo.enable = true;
  };

  settings.global.excludes = [
    "result"
    "result-*"
    ".direnv/**"
    ".git/**"

    # zsh autoload bodies: these are zsh, not POSIX sh. shfmt mangles zsh
    # constructs like ${PWD:t}, so they are formatted by hand.
    "modules/shell/functions/**"

    # Windows-side files that Nix formatters have no business touching.
    "*.ps1"
    "*.lua"
    "windows/whkdrc"
    "windows/scoop-packages.txt"
  ];
}
