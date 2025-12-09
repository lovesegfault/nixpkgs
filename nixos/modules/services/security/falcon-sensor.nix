{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.falcon-sensor;
in
{
  options.services.falcon-sensor = {
    enable = lib.mkEnableOption "CrowdStrike Falcon Sensor";

    package = lib.mkPackageOption pkgs "falcon-sensor" { };

    cid = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        CrowdStrike Customer ID (CID) for sensor registration.

        ::: {.warning}
        This will store the CID in the world-readable Nix store.
        For production deployments, use `cidFile` instead.
        :::
      '';
      example = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX-XX";
    };

    cidFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a file containing the CrowdStrike Customer ID (CID).
        The file should contain only the CID string with no trailing newline.
        This is the recommended way to provide the CID for production use.
      '';
      example = "/run/secrets/falcon-cid";
    };

    provisioningToken = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Provisioning token for sensor installation.

        ::: {.warning}
        This will store the token in the world-readable Nix store.
        For production deployments, use `provisioningTokenFile` instead.
        :::
      '';
    };

    provisioningTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a file containing the provisioning token.
      '';
      example = "/run/secrets/falcon-provisioning-token";
    };

    tags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Sensor grouping tags for policy assignment in the Falcon console.
      '';
      example = [
        "Production"
        "WebServers"
      ];
    };

    proxy = lib.mkOption {
      type = lib.types.submodule {
        options = {
          disable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Disable proxy auto-discovery.";
          };

          host = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Proxy server hostname or IP address.";
            example = "proxy.example.com";
          };

          port = lib.mkOption {
            type = lib.types.nullOr lib.types.port;
            default = null;
            description = "Proxy server port.";
            example = 8080;
          };
        };
      };
      default = { };
      description = "Proxy configuration for Falcon cloud connectivity.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.cid != null || cfg.cidFile != null;
        message = ''
          CrowdStrike Falcon Sensor requires a Customer ID (CID).
          Please set either `services.falcon-sensor.cid` or
          `services.falcon-sensor.cidFile`.
        '';
      }
      {
        assertion = !(cfg.cid != null && cfg.cidFile != null);
        message = ''
          Cannot specify both `services.falcon-sensor.cid` and
          `services.falcon-sensor.cidFile`. Please use only one.
        '';
      }
    ];

    warnings = lib.optional (cfg.cid != null) ''
      services.falcon-sensor.cid is set directly in the configuration.
      This will store your CrowdStrike CID in the world-readable Nix store.
      Consider using services.falcon-sensor.cidFile for production deployments.
    '';

    # Load the kernel module
    boot.extraModulePackages = [ config.boot.kernelPackages.falcon-sensor ];
    boot.kernelModules = [ "falcon-sensor" ];

    # Make falconctl available system-wide
    environment.systemPackages = [ cfg.package ];

    # Create required directories
    systemd.tmpfiles.settings."10-falcon-sensor" = {
      "/opt/CrowdStrike".d = {
        user = "root";
        group = "root";
        mode = "0700";
      };
    };

    systemd.services.falcon-sensor = {
      description = "CrowdStrike Falcon Sensor";
      after = [
        "local-fs.target"
        "network.target"
        "systemd-modules-load.service"
      ];
      wants = [ "systemd-modules-load.service" ];
      wantedBy = [ "multi-user.target" ];

      path = [
        cfg.package
        pkgs.coreutils
      ];

      preStart =
        let
          falconctl = lib.getExe' cfg.package "falconctl";
        in
        ''
          # Configure CID
          ${
            if cfg.cidFile != null then
              ''
                CID=$(cat ${cfg.cidFile})
                ${falconctl} -s --cid="$CID"
              ''
            else
              ''
                ${falconctl} -s --cid="${cfg.cid}"
              ''
          }

          # Configure provisioning token if provided
          ${lib.optionalString (cfg.provisioningTokenFile != null) ''
            TOKEN=$(cat ${cfg.provisioningTokenFile})
            ${falconctl} -s --provisioning-token="$TOKEN"
          ''}
          ${lib.optionalString (cfg.provisioningToken != null) ''
            ${falconctl} -s --provisioning-token="${cfg.provisioningToken}"
          ''}

          # Configure tags
          ${lib.optionalString (cfg.tags != [ ]) ''
            ${falconctl} -s --tags="${lib.concatStringsSep "," cfg.tags}"
          ''}

          # Configure proxy settings
          ${lib.optionalString cfg.proxy.disable ''
            ${falconctl} -s --apd=true
          ''}
          ${lib.optionalString (cfg.proxy.host != null) ''
            ${falconctl} -s --aph="${cfg.proxy.host}"
          ''}
          ${lib.optionalString (cfg.proxy.port != null) ''
            ${falconctl} -s --app="${toString cfg.proxy.port}"
          ''}
        '';

      serviceConfig = {
        Type = "simple";
        ExecStart = "${lib.getExe' cfg.package "falcond"}";
        Restart = "always";
        RestartSec = 10;

        # State and log directories
        StateDirectory = "falcon-sensor";
        StateDirectoryMode = "0700";
        LogsDirectory = "falcon";
        LogsDirectoryMode = "0750";
        RuntimeDirectory = "falcon-sensor";
        RuntimeDirectoryMode = "0755";

        # Falcon requires extensive system access for EDR functionality
        # These settings are intentionally permissive
        PrivateTmp = false;
        PrivateDevices = false;
        PrivateNetwork = false;
        ProtectSystem = false;
        ProtectHome = false;
        ProtectKernelModules = false;
        ProtectKernelTunables = false;
        ProtectControlGroups = false;
        MemoryDenyWriteExecute = false;
        NoNewPrivileges = false;

        # Capabilities required for EDR functionality
        AmbientCapabilities = [
          "CAP_SYS_ADMIN"
          "CAP_SYS_PTRACE"
          "CAP_SYS_RAWIO"
          "CAP_NET_ADMIN"
          "CAP_NET_RAW"
          "CAP_DAC_READ_SEARCH"
          "CAP_AUDIT_WRITE"
          "CAP_AUDIT_CONTROL"
          "CAP_SYSLOG"
          "CAP_SYS_MODULE"
        ];

        # Resource limits
        LimitNOFILE = "1048576";
        LimitNPROC = "infinity";
        LimitCORE = "infinity";

        # Scheduling priority
        Nice = -5;

        # Prevent OOM killer from terminating the security agent
        OOMScoreAdjust = -1000;
      };
    };
  };

  meta.maintainers = with lib.maintainers; [ lovesegfault ];
}
