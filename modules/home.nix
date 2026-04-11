{
  config,
  pkgs,
  lib,
  primary_username,
  git_user_name,
  git_user_email,
  package_sets,
  ...
}:
{
  home = {
    username = primary_username;
    homeDirectory = "/home/${primary_username}";
    stateVersion = "24.11";

    packages = package_sets.shell_tools ++ package_sets.user_apps;

    file.".hushlogin".text = "";

    sessionPath = [ "/home/${primary_username}/.local/bin" ];

    sessionVariables = {
      EDITOR = "hx";
      VISUAL = "hx";

      LANG = "C.UTF-8";
      LC_ALL = "C.UTF-8";

      PYTHONDONTWRITEBYTECODE = "1";
      PYTHONUNBUFFERED = "1";
      PIP_DISABLE_PIP_VERSION_CHECK = "1";

      CLICOLOR = "1";
      BAT_THEME = "Monokai Extended";

      PAGER = "less -FirSwX";
      MANPAGER = "sh -c 'bat -l man -p'";
      LESS = "-FRX";
      LESSHISTFILE = "-";

      GCC_COLORS = "error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01";

      DFT_BACKGROUND = "dark";
      DFT_DISPLAY = "side-by-side-show-both";
    };

    activation.createDirectories = lib.mkAfter ''
      for _d in \
        "$HOME/.local/bin" \
        "$HOME/.local/share" \
        "$HOME/.local/state" \
        "$HOME/.cache" \
        "$HOME/.marks"; do
        [[ -d "$_d" ]] || mkdir -p "$_d"
      done
    '';
  };

  xdg.enable = true;

  programs = {
    zsh = {
      enable = true;
      dotDir = "${config.xdg.configHome}/zsh";
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = false;

      completionInit = ''
        autoload -Uz compinit
        _comp_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
        [[ -d "$_comp_dir" ]] || mkdir -p "$_comp_dir"
        _comp_dump="$_comp_dir/zcompdump-$ZSH_VERSION"
        _hm_gen=$(readlink ~/.local/state/nix/profiles/profile 2>/dev/null || echo "unknown")
        _comp_stamp="$_comp_dir/.comp-generation"
        if [[ -f "$_comp_dump" && -f "$_comp_stamp" && "$_hm_gen" = "$(cat "$_comp_stamp" 2>/dev/null)" ]]; then
          compinit -C -d "$_comp_dump"
        else
          compinit -d "$_comp_dump"
          echo "$_hm_gen" > "$_comp_stamp"
        fi
        unset _comp_dir _comp_dump _hm_gen _comp_stamp
      '';

      history = {
        size = 50000;
        save = 50000;
        ignoreDups = true;
        ignoreSpace = true;
        share = true;
        extended = true;
      };

      initContent = ''
        setopt EXTENDED_GLOB
        setopt GLOB_DOTS
        setopt HIST_FIND_NO_DUPS
        setopt NO_BEEP
        setopt PROMPT_SUBST
        setopt INTERACTIVE_COMMENTS
        unsetopt NOMATCH

        # ─ Tool init bundle (cached) ─
        _init_cache="''${XDG_CACHE_HOME:-$HOME/.cache}/zsh-init"
        [[ -d "$_init_cache" ]] || mkdir -p "$_init_cache"
        _bundle_ver="bundle-${pkgs.zoxide.version}_${pkgs.starship.version}_${pkgs.direnv.version}_${pkgs.atuin.version}_${pkgs.fzf.version}"
        _bundle="$_init_cache/$_bundle_ver.zsh"
        if [[ ! -f "$_bundle" ]]; then
          command rm -f "$_init_cache"/bundle-*.zsh 2>/dev/null || true
          {
            ${pkgs.zoxide}/bin/zoxide init zsh --cmd z
            echo ""
            [[ $TERM != "dumb" ]] && ${pkgs.starship}/bin/starship init zsh
            echo ""
            ${pkgs.direnv}/bin/direnv hook zsh
            echo ""
            echo 'if [[ $options[zle] = on ]]; then'
            ${pkgs.atuin}/bin/atuin init zsh | sed 's/^/  /'
            echo ""
            ${pkgs.fzf}/bin/fzf --zsh | sed 's/^/  /'
            echo 'fi'
          } > "$_bundle"
        fi
        source "$_bundle"
        unset _init_cache _bundle_ver _bundle

        # ─ Cached completions ─
        _cache="''${XDG_CACHE_HOME:-$HOME/.cache}/zsh-completions"
        [[ -d "$_cache" ]] || mkdir -p "$_cache"

        _ghv="$_cache/gh.${pkgs.gh.version}.zsh"
        if [[ ! -f "$_ghv" ]]; then
          command rm -f "$_cache"/gh.*.zsh 2>/dev/null || true
          ${pkgs.gh}/bin/gh completion -s zsh > "$_ghv" 2>/dev/null
        fi
        source "$_ghv"

        _justv="$_cache/just.${pkgs.just.version}.zsh"
        if [[ ! -f "$_justv" ]]; then
          command rm -f "$_cache"/just.*.zsh 2>/dev/null || true
          ${pkgs.just}/bin/just --completions zsh > "$_justv" 2>/dev/null
        fi
        source "$_justv"

        unset _cache _ghv _justv

        # ─ Shell functions ─
        function dev() {
          if [ -f flake.nix ]; then
            nix develop
          else
            local shell="''${1:-default}"
            nix develop "path:$HOME/nix-windows-config#$shell" || echo "dev: shell '$shell' not found"
          fi
        }

        function nixconf() {
          cd ~/nix-windows-config && ''${EDITOR:-hx} .
        }

        function gwt() {
          local branch="$1"
          if [ -z "$branch" ]; then
            echo "Usage: gwt <branch-name>"
            return 1
          fi
          git worktree add "../$(basename $(pwd))-$branch" -b "$branch" 2>/dev/null || \
          git worktree add "../$(basename $(pwd))-$branch" "$branch"
          cd "../$(basename $(pwd))-$branch"
        }

        function mark() {
          local name="''${1:-$(basename $(pwd))}"
          mkdir -p ~/.marks
          ln -sf "$(pwd)" "$HOME/.marks/$name"
          echo "Marked $(pwd) as '$name'"
        }

        function jump() {
          local name="$1"
          if [ -z "$name" ]; then
            ls -la ~/.marks/ 2>/dev/null || echo "No marks set"
            return
          fi
          cd -P "$HOME/.marks/$name" 2>/dev/null || echo "Mark not found: $name"
        }

        # ─ Lazy-loaded helpers ─
        function nix-init() {
          eval "$(cat <<'_LAZY_'
        function nix-init() {
          local template="''${1:-default}"
          if [ -f flake.nix ]; then
            echo "flake.nix already exists in current directory"
            return 1
          fi
          nix flake init -t "github:nix-community/templates#$template"
        }
        _LAZY_
          )"
          nix-init "$@"
        }

        function nix-search() {
          eval "$(cat <<'_LAZY_'
        function nix-search() {
          if [ -z "$1" ]; then echo "Usage: nix-search <query>"; return 1; fi
          nix search nixpkgs#"$1" --json 2>/dev/null | jq -r 'to_entries[] | "\(.key | split(".") | .[-1]): \(.value.description // "No description")"' | head -20
        }
        _LAZY_
          )"
          nix-search "$@"
        }

        function nix-info() {
          eval "$(cat <<'_LAZY_'
        function nix-info() {
          if [ -z "$1" ]; then echo "Usage: nix-info <package>"; return 1; fi
          nix eval nixpkgs#"$1".meta --json 2>/dev/null | jq '.' || echo "Package not found: $1"
        }
        _LAZY_
          )"
          nix-info "$@"
        }

        function nix-which() {
          eval "$(cat <<'_LAZY_'
        function nix-which() {
          if [ -z "$1" ]; then echo "Usage: nix-which <binary>"; return 1; fi
          nix-locate --top-level -w "/bin/$1" 2>/dev/null | head -10
        }
        _LAZY_
          )"
          nix-which "$@"
        }

        function nix-tmp() {
          eval "$(cat <<'_LAZY_'
        function nix-tmp() {
          if [ $# -eq 0 ]; then echo "Usage: nix-tmp <pkg1> [pkg2] ..."; return 1; fi
          local pkgs=""
          for pkg in "$@"; do pkgs="$pkgs nixpkgs#$pkg"; done
          nix shell $pkgs
        }
        _LAZY_
          )"
          nix-tmp "$@"
        }

        function extract() {
          eval "$(cat <<'_LAZY_'
        function extract() {
          if [ -z "$1" ]; then echo "Usage: extract <archive>"; return 1; fi
          if [ -f "$1" ]; then
            case "$1" in
              *.tar.bz2) tar xjf "$1" ;;
              *.tar.gz)  tar xzf "$1" ;;
              *.tar.xz)  tar xJf "$1" ;;
              *.bz2)     bunzip2 "$1" ;;
              *.gz)      gunzip "$1" ;;
              *.tar)     tar xf "$1" ;;
              *.tbz2)    tar xjf "$1" ;;
              *.tgz)     tar xzf "$1" ;;
              *.zip)     unzip "$1" ;;
              *.Z)       uncompress "$1" ;;
              *.7z)      7zz x "$1" ;;
              *.rar)     unrar x "$1" ;;
              *)         echo "Unknown archive format: $1" ;;
            esac
          else
            echo "File not found: $1"
          fi
        }
        _LAZY_
          )"
          extract "$@"
        }

        function vpn-home() {
          eval "$(cat <<'_LAZY_'
        function vpn-home() {
          local conf="/etc/wireguard/home.conf"
          local action="''${1:-toggle}"
          if [[ "$action" == "toggle" ]]; then
            if sudo wg show home &>/dev/null; then action="down"; else action="up"; fi
          fi
          sudo wg-quick "''${action}" "''${conf}"
        }
        _LAZY_
          )"
          vpn-home "$@"
        }

        function net-discover() {
          eval "$(cat <<'_LAZY_'
        function net-discover() {
          local subnet="''${1:-192.168.1.0/24}"
          echo "==> ARP scan: ''${subnet}"
          sudo arp-scan --localnet 2>/dev/null || sudo arp-scan "''${subnet}"
          echo "==> nmap ping sweep: ''${subnet}"
          sudo nmap -sn "''${subnet}"
        }
        _LAZY_
          )"
          net-discover "$@"
        }

        function port-scan() {
          eval "$(cat <<'_LAZY_'
        function port-scan() {
          if [[ -z "$1" ]]; then echo "Usage: port-scan <host> [nmap-args]"; return 1; fi
          local host="$1"; shift
          sudo nmap -sV -sC -O --open -T4 "$@" "''${host}"
        }
        _LAZY_
          )"
          port-scan "$@"
        }

        function vuln-scan() {
          eval "$(cat <<'_LAZY_'
        function vuln-scan() {
          if [[ -z "$1" ]]; then echo "Usage: vuln-scan <host>"; return 1; fi
          sudo nmap -sV --script vuln -T4 "$1"
        }
        _LAZY_
          )"
          vuln-scan "$@"
        }

        function fast-scan() {
          eval "$(cat <<'_LAZY_'
        function fast-scan() {
          if [[ -z "$1" ]]; then echo "Usage: fast-scan <host>"; return 1; fi
          local host="$1"
          local ports
          ports=$(sudo masscan "''${host}" -p1-65535 --rate=1000 2>/dev/null \
            | awk '/Discovered/{print $4}' | cut -d/ -f1 | sort -n | paste -sd,)
          if [[ -z "$ports" ]]; then echo "No open ports found."; return 0; fi
          echo "==> Open ports: ''${ports}"
          sudo nmap -sV -sC -p "''${ports}" "''${host}"
        }
        _LAZY_
          )"
          fast-scan "$@"
        }

        function web-scan() {
          eval "$(cat <<'_LAZY_'
        function web-scan() {
          if [[ -z "$1" ]]; then echo "Usage: web-scan <host|url>"; return 1; fi
          nikto -h "$@"
        }
        _LAZY_
          )"
          web-scan "$@"
        }

        source ${pkgs.zsh-fast-syntax-highlighting}/share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
      '';

      loginExtra = ''
        [ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
      '';
    };

    starship = {
      enable = true;
      enableZshIntegration = false;
      settings = {
        add_newline = false;
        command_timeout = 300;
        palette = "default";

        format = "$directory$git_branch$git_status$cmd_duration$character";

        palettes.default = {
          prompt_ok = "#8047c1";
          prompt_err = "#e23140";
          icon = "#161514";
          background = "#35312c";
          directory = "#9f31e2";
          status = "#e23140";
          git_branch = "#31e268";
          git_status = "#31e268";
          cmd_duration = "#e26f31";
          duration = "#e26f31";
        };

        character = {
          success_symbol = "[❯](fg:prompt_ok bold)";
          error_symbol = "[❯](fg:prompt_err bold)";
        };

        directory = {
          format = "[](fg:directory)[](fg:icon bg:directory)[](fg:directory bg:background)[ $path ](bg:background)[](fg:background)";
          truncate_to_repo = false;
          truncation_length = 3;
          truncation_symbol = "…/";
          substitutions = {
            "Documents" = "󰈙";
            "Downloads" = "";
            "Music" = "󰝚";
            "Pictures" = "";
            "Desktop" = "󰟡";
            "Repos" = "󰲋";
          };
        };

        git_branch = {
          format = "[](fg:git_branch)[](fg:icon bg:git_branch)[](fg:git_branch bg:background)[ $branch ](bg:background)";
          disabled = false;
        };

        git_status = {
          format = "[](fg:git_status)[$all_status$ahead_behind](fg:icon bg:git_status)[](fg:git_status)";
          disabled = false;
        };

        cmd_duration = {
          format = "[](fg:cmd_duration)[ $duration ](fg:icon bg:cmd_duration)[](fg:cmd_duration)";
          min_time = 2000;
          disabled = false;
        };
      };
    };

    fzf = {
      enable = true;
      enableZshIntegration = false;
      defaultCommand = "fd --type f --hidden --follow --exclude .git";
      fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
      changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
      defaultOptions = [
        "--height=40%"
        "--layout=reverse"
        "--border=rounded"
        "--inline-info"
      ];
    };

    bat = {
      enable = true;
      config = {
        theme = "Monokai Extended";
        style = "numbers,changes,header,grid";
        italic-text = "always";
      };
    };

    eza = {
      enable = true;
      enableZshIntegration = true;
      icons = "auto";
      git = false;
      extraOptions = [
        "--group-directories-first"
        "--header"
      ];
    };

    ripgrep.enable = true;
    fd = {
      enable = true;
      hidden = true;
      ignores = [
        ".git"
        "node_modules"
        ".cache"
      ];
    };

    zoxide = {
      enable = true;
      enableZshIntegration = false;
      options = [ "--cmd z" ];
    };

    direnv = {
      enable = true;
      enableZshIntegration = false;
      nix-direnv.enable = true;
    };

    btop = {
      enable = true;
      settings = {
        color_theme = "Default";
        update_ms = 500;
        theme_background = false;
        vim_keys = true;
        rounded_corners = true;
      };
    };

    atuin = {
      enable = true;
      enableZshIntegration = false;
      daemon.enable = false;
      settings = {
        auto_sync = false;
        search_mode = "fuzzy";
        filter_mode = "global";
        style = "compact";
        show_preview = true;
        keymap_mode = "vim-normal";
      };
    };

    git = {
      enable = true;
      signing.format = null;
      settings = {
        user = {
          name = git_user_name;
          email = git_user_email;
        };

        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
        branch.autosetuprebase = "always";
        fetch = {
          prune = true;
          pruneTags = true;
          fsckobjects = true;
        };

        core = {
          editor = "hx";
          fsmonitor = true;
          untrackedCache = true;
          commitGraph = true;
        };

        log.date = "iso";
        help.autocorrect = "prompt";
        column.ui = "auto";

        diff = {
          tool = "difftastic";
          algorithm = "histogram";
        };
        difftool = {
          prompt = false;
          difftastic.cmd = "difft \"$LOCAL\" \"$REMOTE\"";
        };

        merge.conflictstyle = "zdiff3";
        rerere.enabled = true;

        transfer.fsckobjects = true;
        receive.fsckobjects = true;

        rebase = {
          autoSquash = true;
          autoStash = true;
          updateRefs = true;
        };

        alias = {
          difft = "difftool --tool difftastic --no-prompt";
          cleanup = "!git branch --merged | grep -v '\\*\\|master\\|main\\|develop' | xargs -n 1 -r git branch -d";
          prettylog = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
          lg = "log --oneline --decorate --graph";
          lga = "log --oneline --decorate --graph --all";
          root = "rev-parse --show-toplevel";
          amend = "commit --amend --no-edit";
          fixup = "commit --fixup";
          wip = "commit -am 'WIP'";
          undo = "reset --soft HEAD~1";
          stash-all = "stash save --include-untracked";
          unstash = "stash pop";
          s = "status -sb";
          co = "checkout";
          cb = "checkout -b";
          cm = "commit -m";
          sync = "!git fetch --all --prune && git pull --rebase";
        };
      };
      ignores = [
        ".DS_Store"
        ".AppleDouble"
        ".LSOverride"
        "._*"
        "*.swp"
        "*.swo"
        "*~"
        ".idea/"
        ".vscode/"
        "*.sublime-*"
        "result"
        "result-*"
        ".direnv/"
        "__pycache__/"
        "*.pyc"
        ".venv/"
        ".mypy_cache/"
        ".pytest_cache/"
        ".ruff_cache/"
        "node_modules/"
        ".env"
        ".env.local"
        ".env.*.local"
      ];
    };

    gh = {
      enable = true;
      settings = {
        git_protocol = "https";
        editor = "hx";
        prompt = "enabled";
        aliases = {
          co = "pr checkout";
          pv = "pr view";
          pc = "pr create";
        };
      };
    };

    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        syntax-theme = "Monokai Extended";
        line-numbers = true;
        side-by-side = false;
        file-style = "bold yellow ul";
        file-decoration-style = "none";
        hunk-header-style = "omit";
        navigate = true;
      };
    };

    difftastic.enable = true;

    helix = {
      enable = true;
      defaultEditor = true;
      settings = {
        theme = "monokai_pro_oled";

        editor = {
          line-number = "relative";
          mouse = true;
          cursorline = true;
          color-modes = true;
          idle-timeout = 0;
          completion-trigger-len = 1;
          true-color = true;
          rulers = [ 100 ];
          bufferline = "multiple";

          cursor-shape = {
            insert = "bar";
            normal = "block";
            select = "underline";
          };

          file-picker = {
            hidden = false;
            git-ignore = true;
          };

          lsp = {
            display-messages = true;
            display-inlay-hints = true;
          };

          statusline = {
            left = [
              "mode"
              "spinner"
              "file-name"
              "file-modification-indicator"
            ];
            center = [ ];
            right = [
              "diagnostics"
              "selections"
              "position"
              "file-encoding"
              "file-line-ending"
              "file-type"
            ];
            separator = "|";
          };

          indent-guides = {
            render = true;
            character = "|";
          };

          soft-wrap.enable = true;
        };

        keys = {
          normal = {
            space = {
              q = ":q";
              w = ":w";
              x = ":x";
              f = "file_picker";
              b = "buffer_picker";
              s = "symbol_picker";
              a = "code_action";
              r = "rename_symbol";
              d = "goto_definition";
              D = "goto_declaration";
              y = "yank_to_clipboard";
            };
            "C-h" = "jump_view_left";
            "C-j" = "jump_view_down";
            "C-k" = "jump_view_up";
            "C-l" = "jump_view_right";
          };

          insert = {
            "C-space" = "completion";
          };
        };
      };

      themes.monokai_pro_oled = {
        inherits = "monokai_pro";
        "ui.background".bg = "#000000";
      };

      languages = {
        language-server = {
          nixd.command = "nixd";
          ruff-lsp = {
            command = "ruff";
            args = [ "server" ];
          };
          taplo = {
            command = "taplo";
            args = [
              "lsp"
              "stdio"
            ];
          };
        };

        language = [
          {
            name = "nix";
            auto-format = true;
            formatter.command = "nixfmt";
            language-servers = [ "nixd" ];
          }
          {
            name = "python";
            auto-format = true;
            formatter = {
              command = "ruff";
              args = [
                "format"
                "-"
              ];
            };
            language-servers = [ "ruff-lsp" ];
          }
          {
            name = "toml";
            auto-format = true;
            formatter = {
              command = "taplo";
              args = [
                "fmt"
                "-"
              ];
            };
            language-servers = [ "taplo" ];
          }
        ];
      };
    };

    nix-index.enable = true;
  };

  # ─ Weekly Nix garbage collection (mirrors macOS launchd job) ─
  systemd.user = {
    services.nix-gc = {
      Unit.Description = "Nix garbage collection (delete generations >30 days)";
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.nix}/bin/nix-collect-garbage --delete-older-than 30d";
      };
    };
    timers.nix-gc = {
      Unit.Description = "Weekly Nix garbage collection";
      Timer = {
        OnCalendar = "Sun *-*-* 02:00:00";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };

  home.shellAliases = {
    tree = "erd --human";
    find = "fd";
    grep = "rg";
    cat = "bat --paging=never";
    less = "bat --paging=always";

    ps = "procs";
    du = "dust";
    df = "duf";
    top = "btop";

    lsg = "eza --git";
    llg = "eza -l --git";

    tl = "tldr";
    ping = "gping";
    curl = "xh";
    dig = "dog";

    ports = "ss -tlnp";
    pubip = "command curl -s https://ipinfo.io/ip";

    ".." = "cd ..";
    "..." = "cd ../..";
    "...." = "cd ../../..";

    rm = "rm -i";
    cp = "cp -i";
    mv = "mv -i";

    g = "git";
    gs = "git status";
    gd = "git diff";
    gds = "git diff --staged";
    ga = "git add";
    gc = "git commit";
    gp = "git push";
    gl = "git prettylog";
    gco = "git checkout";
    gb = "git branch";
  };
}
