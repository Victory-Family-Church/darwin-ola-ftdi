{
  description = "OLA with FTDI DMX support (nix-darwin module)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-darwin.url = "github:LnL7/nix-darwin";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      overlay = final: prev: {
        olaftdi = prev.ola.overrideAttrs (old: {
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
      # Expose overlay
      overlays.default = overlay;

      # nix-darwin module
      darwinModules.ola-ftdi = { config, pkgs, lib, ... }:
        let
          cfg = config.services.ola-ftdi;

          oladArgs =
            [
              "${cfg.package}/bin/olad"
              "--daemon"
            ]
            ++ lib.optionals (!cfg.web.enable) [ "--no-httpd" ]
            ++ lib.optionals cfg.web.enable [
              "--http-port" (toString cfg.web.port)
              "--http-interface" cfg.web.host
            ];
        in
        {
          options.services.ola-ftdi = {
            enable = lib.mkEnableOption "OLA with FTDI DMX support";

            package = lib.mkOption {
              type = lib.types.package;
              default = pkgs.olaftdi;
              description = "OLA package with FTDI";
            };

            web = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Enable OLA web UI";
              };

              port = lib.mkOption {
                type = lib.types.port;
                default = 9090;
                description = "Port for OLA web UI";
              };

              host = lib.mkOption {
                type = lib.types.str;
                default = "127.0.0.1";
                description = "Interface to bind OLA web UI";
              };
            };

            usb = {
              enableFtdi = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Enable FTDI USB access helpers";
              };
            };
          };

          config = lib.mkIf cfg.enable {
            nixpkgs.overlays = [ overlay ];

            environment.systemPackages = [
              cfg.package
              pkgs.libftdi1
              pkgs.libusb1
            ];

            # Launchd service
            launchd.daemons.ola = {
              serviceConfig = {
                ProgramArguments = oladArgs;
                KeepAlive = true;
                RunAtLoad = true;

                StandardOutPath = "/tmp/olad.log";
                StandardErrorPath = "/tmp/olad.err";

                # Needed for USB access
                UserName = "root";
              };
            };

            # macOS USB / FTDI handling
            system.activationScripts.ola-ftdi-usb.text =
              lib.mkIf cfg.usb.enableFtdi ''
                echo "Configuring FTDI access for OLA..."

                /usr/sbin/system_profiler SPUSBDataType | grep -i ftdi || true

                echo "NOTE:"
                echo "- If OLA cannot access the device,"
                echo "  try unloading Apple's FTDI driver:"
                echo "  sudo kextunload -b com.apple.driver.AppleUSBFTDI"
              '';
          };
        };
    }
    //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
           problems.handlers = {
             ola.broken = "warn"; # or "ignore"
           };
         };
          overlays = [ overlay ];
        };
      in
      {
        packages.default = pkgs.olaftdi;

        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.olaftdi
            pkgs.libusb1
            pkgs.libftdi1
          ];

          shellHook = ''
            echo "🔧 OLA FTDI Dev Shell"
            echo ""
            echo "Run:"
            echo "  olad --http-port 9090 --http-interface 127.0.0.1"
            echo "  ola_dev_info"
            echo ""
            export OLA_LOG_LEVEL=4
          '';
        };
      }
    );
}