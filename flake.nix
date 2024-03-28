{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs"; # unstable nixpkgs
  };

  outputs = { self, nixpkgs, ... } @ inputs:
  let
    system = "x86_64-linux";
    pkgsUnstable = import nixpkgs { inherit system; };
  in
  {
    nixosModules.default = { config, lib, ... }: {
      options = {};
      config =
      let
        dockerEnabled = config.virtualisation.docker.rootless.enable;
      in
      lib.mkIf (dockerEnabled) {
        # --- run prometheus
        services.prometheus = {
          enable = true;
          port = 9001;
          exporters = {
            node = {
              enable = true;
              enabledCollectors = [ "systemd" ];
              port = 9002;
            };
          };
          scrapeConfigs = [
            {
              job_name = "system";
              static_configs = [{
                targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
              }];
            }
          ];
        };

        # --- run loki
        services.loki = {
          enable = true;
          configFile = ./loki-config.yml;
        };

        # --- run promtail
        systemd.services.promtail = {
          description = "Promtail service for Loki";
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            ExecStart = ''
              ${pkgsUnstable.grafana-loki}/bin/promtail --config.file ${./promtail-config.yml}
            '';
          };
        };

        # --- configurat docker logs for promtail to ingest logs
        virtualisation.docker.rootless.daemon.settings = {
          log-driver = lib.mkDefault "journald";
          log-opts = {
            labels = "level,msg,ts"; # for application logs formatted as json-lines
            tag = "{{.Name}}"; # container name instead of container id
          };
        };

        # --- run grafana
        services.grafana = {
          enable = true;
#          domain = "example.com";

          settings = {
            server = {
              http_port = 2342;
              http_addr = "127.0.0.1";
            };
            security = {
              admin_user = "admin";
              admin_password = "admin"; # default. admin can change upon logging in
            };
          };

          provision = {
            enable = true;
            datasources.settings = {
              datasources = [
                {
                  name = "Prometheus";
                  type = "prometheus";
                  url = "http://127.0.0.1:9001";
                }
                {
                  name = "Loki";
                  type = "loki";
                  url = "http://127.0.0.1:3100";
                  apiVersion = 1;
                }
              ];
            };
          };
        };
      };
    };
  };
}
