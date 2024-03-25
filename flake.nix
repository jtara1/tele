{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs"; # unstable nixpkgs
  };

  outputs = { self, nixpkgs, ... } @ inputs: {
    nixosModules.default = { config, lib, ... }: {
      options = {};
      config = lib.mkIf (config.virtualisation.docker.rootless.enable) {
        # --- run loki
        services.loki = {
          enable = true;
          useLocally = true; # simplification assumption - logs-app runs local to apps
        };

        # --- run grafana
        services.grafana = {
          enable = true;
          settings = {
            security = {
              admin_user = "admin";
              admin_password = "admin"; # FIXME: parameterize through build args or options
            };
          };
          provision = {
            enable = true;
            datasources.apiVersion = 1;
            datasources.settings = [
              {
                name = "Loki";
                type = "loki";
                access = "proxy";
                url = "http://localhost:3100";
                jsonData.maxLines = 1000;
                jsonData.tlsSkipVerify = true;
                isDefault = true;
              }
            ];
          };
        };

        # --- in docker daemon.json (settings), enable docker loki plugin
        virtualisation.docker.rootless.daemon.settings = {
          log-driver = lib.mkDefault "loki";
          log-opts = {
            # in general, for json-line logs with properties
            labels = "level,msg,ts";
            # for loki
            loki-url = "http://localhost:3100/loki/api/v1/push";
            loki-batch-size = "400";
            loki-pipeline-stages = ''
              - json:
                  expressions:
                    level: level
                    msg: msg
                    ts: ts
              - labels:
                  level: level
                  msg: msg
                  ts: ts
            '';
          };
        };

        # --- systemd oneshot to install docker loki plugin
        systemd.services = {
          # TODO: This needs more testing. Is docker available before docker.service? but after the service would err out bc daemon.json requires loki plugin
          # the `docker plugin install` should just be done manually until further testing/fix
          dockerPluginLokiInstall = {
            wantedBy = [ "multi-user.target" ];
            before = [ "docker.service" ];
            requires = [ "docker.service" ];
            description = "Install docker plugin, loki.";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = ''
                /bin/sh -c '
                  if ! docker plugin ls --filter enabled=true | grep -q loki; then
                    docker plugin install grafana/loki-docker-driver:2.9.4 --alias loki --grant-all-permissions
                  fi
                '
              '';
            };
          };
        };
      };
    };
  };
}
