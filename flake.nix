{
  description = "Windows (WSL2 + home-manager) config — port of nix-darwin-config for Windows host";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # treefmt-nix: drives `nix fmt` / `just fmt` / `just fmt-check`
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, ... }@inputs:
    let
      system = "x86_64-linux";

      primary_username = "blare";
      git_user_name = "blare";
      git_user_email = "blareware@gmail.com";

      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      package_sets = import ./packages.nix { inherit pkgs; };

      treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
    in
    {
      homeConfigurations.wsl = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          inherit inputs;
          inherit primary_username git_user_name git_user_email;
          inherit package_sets;
        };
        modules = [
          inputs.nix-index-database.homeModules.nix-index
          ./modules/home.nix
        ];
      };

      formatter.${system} = treefmtEval.config.build.wrapper;

      checks.${system}.formatting = treefmtEval.config.build.check self;

      devShells.${system}.default = pkgs.mkShell {
        packages = package_sets.dev.shared ++ package_sets.dev.python;
      };
    };
}
