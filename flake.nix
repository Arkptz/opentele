{
  description = "Application packaged using poetry2nix";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:arkptz/nixpkgs/nixos-unstable";
    nixpkgs_redis = {
      url = "github:nixos/nixpkgs?rev=e1ee359d16a1886f0771cc433a00827da98d861c";
    }; # memory leak on unstable

    poetry2nix = {
      url = "github:arkptz/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    flake-utils,
    poetry2nix,
    nixpkgs,
    nixpkgs_redis,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      # pkgs = nixpkgs.legacyPackages.${system};
      pkgs = import nixpkgs {
        inherit system;
        # Переопределение пакетов из nixpkgs_redis, если это необходимо
        overlays = [
          (self: super: {
            redis = (import nixpkgs_redis {inherit system;}).redis;
            # curio = (import nixpkgs-stable {inherit system;}).curio;
          })
          poetry2nix.overlays.default
        ];
      };

      inherit (poetry2nix.lib.mkPoetry2Nix {inherit pkgs;}) mkPoetryApplication mkPoetryEnv overrides cleanPythonSources;

      cleanSources = cleanPythonSources {src = ./.;};
      defaultPython = pkgs.python3;
      # pythonPackages = pkgs.python311Packages;
      pythonPackages = defaultPython.pkgs;
      defaultOverrides =
        overrides.withDefaults
        (
          self: super: {
          }
        );

      defaultAttrs = {
        projectDir = cleanSources;
        python = defaultPython;
        overrides = defaultOverrides;
      };
    in {
      devShells.default = let
        poetryEnv = mkPoetryEnv defaultAttrs;
        makeLibraryPath = packages: pkgs.lib.concatStringsSep ":" (map (package: "${pkgs.lib.getLib package}/lib") packages);
        libs = with pkgs; [glib gtk3 stdenv.cc.cc.lib];
      in
        pkgs.mkShell {
          # inputsFrom = [self.packages.${system}.myapp];
          nativeBuildInputs = with pkgs; [
            poetry
            nixpkgs-fmt
            pre-commit
            # poetry2nix
          ];
          buildInputs = libs;
          packages = with pkgs; [
            poetryEnv
            poetry
          ];
          # packages = with pkgs; [
          #   poetryEnv
          #   poetry
          #   # pkg-config
          #   # clang
          #   # gnumake
          #   # cmake
          #   # gcc
          #   # stdenv.cc.cc.lib
          #   # polylith
          # ];
          NIX_LD_LIBRARY_PATH = makeLibraryPath libs;
          shellHook = ''
            unset SOURCE_DATE_EPOCH
            export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH:$LD_LIBRARY_PATH
            export PYTHONPATH=$PYTHONPATH:${poetryEnv}/lib/python:${poetryEnv}/lib/python3.11/site-packages
            ln -sfT ${poetryEnv.out} ./.venv
          '';
        };
    });
}
