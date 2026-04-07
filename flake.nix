{
  description = "OLA with FTDI DMX support (overlay-based)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      # Define overlay
      overlay = final: prev: {
        ola-ftdi = prev.ola.overrideAttrs (old: {
          buildInputs = (old.buildInputs or []) ++ [ final.libftdi1 ];

          configureFlags = (old.configureFlags or []) ++ [
            "--enable-ftdidmx"
          ];

          env = (old.env or {}) // {
            NIX_CFLAGS_COMPILE = "-Wno-error";
          };
        });
      };
    in
    {
      # Expose overlay so other flakes can use it
      overlays.default = overlay;
    }
    //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;

          overlays = [ overlay ];

          config = {
            allowUnfree = false;
            problems.handlers = {
              ola.broken = "warn"; # or "ignore"
            };
          };
        };
      in {
        packages.default = pkgs.ola;

        devShells.default = pkgs.mkShell {
          buildInputs = [ pkgs.ola ];
        };
      }
    );
}