{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.services.klipper;
  package = pkgs.klipper;
  format = pkgs.formats.ini { mkKeyValue = generators.mkKeyValueDefault {} ":"; };
in
{
  ##### interface
  options = {
    services.klipper = {
      enable = mkEnableOption "Klipper, the 3D printer firmware";

      settings = mkOption {
        type = format.type;
        default = { };
        description = ''
          Configuration for Klipper. See the <link xlink:href="https://www.klipper3d.org/Overview.html#configuration-and-tuning-guides">documentation</link>
          for supported values.
        '';
      };
    };
  };

  ##### implementation
  config = mkIf cfg.enable {
    systemd.services.klipper = {
      description = "Klipper 3D Printer Firmware";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        WorkingDirectory = "${package}/lib";
        RuntimeDirectory = "klipper";
        DynamicUser = true;
        User = "klipper";
        ExecStart = "${package}/lib/klippy.py --input-tty=/run/klipper/tty ${format.generate "klipper.cfg" cfg.settings}";
        SupplementaryGroups = [ "dialout" ];
      };
    };
  };
}
