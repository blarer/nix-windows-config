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

        source ${pkgs.zsh-fast-syntax-highlighting}/share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh

        function dev() {
          if [ -f flake.nix ]; then nix develop; else nix develop "path:$HOME/nix-darwin-config#''${1:-default}"; fi
        }
        function nixconf() { cd ~/nix-darwin-config && ''${EDITOR:-hx} .; }
      '';
    };

    starship = {
      enable = true;
      enableZshIntegration = false;
      settings = {
        add_newline = false;
        command_timeout = 300;
        format = "$directory$git_branch$git_status$cmd_duration$character";
        character = {
          success_symbol = "[❯](purple bold)";
          error_symbol = "[❯](red bold)";
        };
        directory = {
          truncate_to_repo = false;
          truncation_length = 3;
        };
        cmd_duration.min_time = 2000;
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
        fetch = {
          prune = true;
          pruneTags = true;
        };
        core.editor = "hx";
        diff.algorithm = "histogram";
        merge.conflictstyle = "zdiff3";
        rerere.enabled = true;
        alias = {
          s = "status -sb";
          co = "checkout";
          cb = "checkout -b";
          cm = "commit -m";
          lg = "log --oneline --decorate --graph";
          lga = "log --oneline --decorate --graph --all";
          prettylog = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
        };
      };
      ignores = [
        ".DS_Store"
        "*.swp"
        "*~"
        ".idea/"
        ".vscode/"
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
      ];
    };

    gh = {
      enable = true;
      settings = {
        git_protocol = "https";
        editor = "hx";
      };
    };

    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        syntax-theme = "Monokai Extended";
        line-numbers = true;
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
          true-color = true;
          rulers = [ 100 ];
          bufferline = "multiple";
          cursor-shape = {
            insert = "bar";
            normal = "block";
            select = "underline";
          };
          lsp.display-messages = true;
          indent-guides.render = true;
          soft-wrap.enable = true;
        };
        keys.normal.space = {
          q = ":q";
          w = ":w";
          f = "file_picker";
          b = "buffer_picker";
          d = "goto_definition";
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
        ];
      };
    };

    nix-index.enable = true;
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
