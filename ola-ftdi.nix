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
        NIX_CFLAGS_COMPILE = "-Wno-error";
      };
    });
  };
in
{
  ############################
  # Options
  ############################
  options.services.ola-ftdi = {
    enable = lib.mkEnableOption "OLA with FTDI DMX support";

    user = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "Existing system user to run OLA as (not created).";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.olaftdi;
      description = "FTDI-enabled OLA package.";
    };

    web = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 9090;
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
      };
    };

    usb.enableFtdi = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  ############################
  # Configuration
  ############################
  config = lib.mkIf cfg.enable {

    nixpkgs.overlays = [ olaFtdiOverlay ];

    environment.systemPackages = [
      cfg.package
      pkgs.libusb1
      pkgs.libftdi1
    ];

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

    system.activationScripts.ola-ftdi-usb.text =
      lib.mkIf cfg.usb.enableFtdi ''
        echo "🔌 OLA FTDI USB check:"
        /usr/sbin/system_profiler SPUSBDataType | grep -i ftdi || true
      '';
  };
}