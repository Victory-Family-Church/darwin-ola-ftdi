{ config, pkgs, lib, ... }:

let
  cfg = config.services.ola-ftdi;

  # Local overlay: OLA with FTDI enabled
  olaFtdiOverlay = final: prev: {
    olaftdi = prev.ola.overrideAttrs (old: {
      configureFlags =
        (old.configureFlags or []) ++ [ "--enable-ftdidmx" ];

      buildInputs =
        (old.buildInputs or []) ++ [
          final.libftdi1
          final.libusb1
        ];

      env = (old.env or {}) // {
        # OLA produces warnings treated as errors on Darwin
        NIX_CFLAGS_COMPILE = "-Wno-error";
      };
    });
  };
in
{
  ###########################################################################
  # Options
  ###########################################################################
  options.services.ola-ftdi = {
    enable = lib.mkEnableOption "OLA with FTDI DMX support";

    user = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = ''
        Existing system user account to run the OLA daemon as.
        This module does not create the user.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.olaftdi;
      description = "FTDI‑enabled OLA package.";
    };

    web = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable OLA web UI.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 9090;
        description = "Port for the OLA web UI.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Interface to bind the OLA web UI.";
      };
    };

    usb.enableFtdi = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Emit FTDI USB helper notes during activation.";
    };
  };

  ###########################################################################
  # Configuration
  ###########################################################################
  config = lib.mkIf cfg.enable {

    # Apply the local FTDI overlay
    nixpkgs.overlays = [ olaFtdiOverlay ];

    # Allow broken OLA explicitly (Darwin-only system)
    nixpkgs.config.problems.handlers = {
      ola.broken = "ignore";
    };

    # Make OLA and dependencies available
    environment.systemPackages = [
      cfg.package
      pkgs.libusb1
      pkgs.libftdi1
    ];

    # launchd daemon (Darwin-correct schema)
    launchd.daemons.ola = {
      script = ''
        set -eu

        exec ${cfg.package}/bin/olad \
          --daemon \
          ${lib.optionalString (!cfg.web.enable) "--no-httpd"} \
          ${lib.optionalString cfg.web.enable "--http-port ${toString cfg.web.port}"} \
          ${lib.optionalString cfg.web.enable "--http-interface ${cfg.web.host}"}
      '';

      serviceConfig = {
        RunAtLoad = true;
        KeepAlive = true;
        UserName = cfg.user;
        StandardOutPath = "/tmp/olad.log";
        StandardErrorPath = "/tmp/olad.err";
      };
    };

    # Optional FTDI helper notes
    system.activationScripts.ola-ftdi-usb.text =
      lib.mkIf cfg.usb.enableFtdi ''
        echo "🔌 OLA FTDI USB check:"
        /usr/sbin/system_profiler SPUSBDataType | grep -i ftdi || true

        echo ""
        echo "NOTE:"
        echo "If OLA cannot access an FTDI device, you may need to unload"
        echo "Apple's FTDI driver:"
        echo "  sudo kextunload -b com.apple.driver.AppleUSBFTDI"
      '';
  };
}
``