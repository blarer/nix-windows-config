{ pkgs }:
let
  runtimes = {
    python = pkgs.python314FreeThreading;
  };
in
{
  inherit runtimes;

  shell_tools = with pkgs; [
    nmap
    masscan
    nikto
    arp-scan
    wireguard-tools

    sd
    procs
    dust
    duf
    bandwhich
    gping
    dog
    xh
    erdtree
    nnn

    fswatch
    _7zz
    unrar
    opencode
    claude-code

    fastfetch
    hyperfine
    tokei
    just

    nvd
    nix-output-monitor
    deadnix
    statix

    curl
    wget
    uutils-coreutils-noprefix
  ];

  user_apps = with pkgs; [
    nixd
    nixfmt # Nix formatter (used by Helix auto-format and treefmt)
    ruff
    taplo
    tealdeer
    nodejs

    mosh
    jq
    yq-go
  ];

  dev = {
    shared = with pkgs; [
      pkg-config
      openssl
      cacert
    ];

    python = with pkgs; [
      uv
      pyright
    ];
  };
}
