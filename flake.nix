{
  description = "OLA with FTDI DMX support (Nixpkgs overlay)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      overlay = final: prev: {
        olaftdi = prev.ola.overrideAttrs (old: {
          buildInputs = (old.buildInputs or []) ++ [
            final.libftdi1
          ];

          configureFlags = (old.configureFlags or []) ++ [
            "--enable-ftdidmx"
          ];

          env = (old.env or {}) // {
            # OLA treats warnings as errors on Darwin
            NIX_CFLAGS_COMPILE = "-Wno-error";
          };
        });
      };
    in
    {
      # Expose the overlay
      overlays.default = overlay;
    }
    //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
          config = {
            problems.handlers = {
              ola.broken = "warn"; # or "ignore"
            };
          };
        };
      in
      {
        # Make `nix build .#olaftdi` work
        packages = {
          olaftdi = pkgs.olaftdi;
          default = pkgs.olaftdi;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.olaftdi
            pkgs.libusb1
            pkgs.libftdi1
          ];

          shellHook = ''
            echo "🔧 OLA FTDI Dev Shell"
            echo ""
            echo "Try:"
            echo "  olad --http-port 9090 --http-interface 127.0.0.1"
            echo "  ola_dev_info"
            echo ""
            export OLA_LOG_LEVEL=4
          '';
        };
      }
    );
}
