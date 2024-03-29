{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs"; # unstable nixpkgs
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgsUnstable = import nixpkgs { inherit system; };
    in {
      nixosModules.default = { config, lib, ... }: {
        options.services.logs-app = {
          mdDoc = ''
            This module provides a configuration for the Logs App service, which is responsible for collecting and managing logs from various sources.

            The Logs App service includes components for log ingestion, storage, and visualization. It integrates with tools like Loki for log storage and Grafana for log visualization.

            By enabling this module, you enable several services which include:
              - grafana http://localhost:3010
              - prometheus http://localhost:3020
              - loki http://localhost:3030
              - promtail http://localhost:3031

            Promtail will ingest logs from:
              - docker (rootless) containers
          '';

          enable = lib.mkOption {
            type = types.bool;
            default = true;
            example = false;
            description = "Enable the Logs App";
          };
        };

        config = let cfg = config.services.logs-app;
        in lib.mkIf cfg.enable {
          # source: (forked) https://gist.github.com/rickhull/895b0cb38fdd537c1078a858cf15d63e

          # prometheus: port 3020
          #
          services.prometheus = {
            port = 3020;
            enable = true;

            exporters = {
              node = {
                port = 3021;
                enabledCollectors = [ "systemd" ];
                enable = true;
              };
            };

            # ingest the published nodes
            scrapeConfigs = [{
              job_name = "nodes";
              static_configs = [{
                targets = [
                  "127.0.0.1:${
                    toString config.services.prometheus.exporters.node.port
                  }"
                ];
              }];
            }];
          };

          # loki: port 3030
          #
          services.loki = {
            enable = true;
            configuration = {
              auth_enabled = false;

              server = { http_listen_port = 3030; };

              common = {
                instance_addr = "127.0.0.1";
                path_prefix = "/var/lib/loki";
                storage = {
                  filesystem = {
                    chunks_directory = "/var/lib/loki/chunks";
                    rules_directory = "/var/lib/loki/rules";
                  };
                };
                replication_factor = 1;
                ring = { kvstore = { store = "inmemory"; }; };
              };

              schema_config = {
                configs = [{
                  from = "2020-10-24";
                  store = "tsdb";
                  object_store = "filesystem";
                  schema = "v12";
                  index = {
                    prefix = "index_";
                    period = "24h";
                  };
                }];
              };

              ruler = { alertmanager_url = "http://localhost:9093"; };

              analytics = { reporting_enabled = false; };
            };
            # user, group, dataDir, extraFlags, (configFile)
          };

          # promtail: port 3031
          #
          services.promtail = {
            enable = true;
            configuration = {
              server = {
                http_listen_port = 3031;
                grpc_listen_port = 0;
              };

              positions = { filename = "/tmp/positions.yaml"; };

              clients = [{ url = "http://127.0.0.1:${
                toString
                config.services.loki.configuration.server.http_listen_port
              }/loki/api/v1/push"; }];

              scrape_configs = [{
                job_name = "docker";
                docker_sd_configs = [{
                  host = "unix:///run/user/1000/docker.sock";
                  refresh_interval = "5s";
                }];
                relabel_configs = [
                  {
                    source_labels = [ "__meta_docker_container_name" ];
                    target_label = "container";
                    regex = "/(.+)"; # renames /my_container to my_container
                    replacement = "$1";
                  }
                  {
                    source_labels = [ "__meta_docker_container_log_stream" ];
                    target_label = "logstream";
                  }
                  {
                    source_labels = [ "__meta_docker_container_image" ];
                    target_label = "image";
                  }
                ];
                pipeline_stages = [{
                  docker = { stop_grace_period = "1m"; };
                }]; # continue to read logs after container exits
              }];
            };
            # extraFlags
          };

          # grafana: port 3010
          #
          services.grafana = {
            port = 3010;
            protocol = "http";
            addr = "127.0.0.1";
            analytics.reporting.enable = false;
            enable = true;
            provision = {
              enable = true;
              datasources.settings = {
                datasources = [
                  {
                    name = "Prometheus";
                    type = "prometheus";
                    access = "proxy";
                    url = "http://127.0.0.1:${
                        toString config.services.prometheus.port
                      }";
                  }
                  {
                    name = "Loki";
                    type = "loki";
                    access = "proxy";
                    url = "http://127.0.0.1:${
                        toString
                        config.services.loki.configuration.server.http_listen_port
                      }";
                  }
                ];
              };
            };
          };

          # nginx upstreams to alias several services "${ip}:${port}"
          # note: this isn't defining nginx config (services.nginx)
          # note: this is for use within your system nginx config
          #
          nginx = {
            upstreams = {
              "grafana" = {
                servers = {
                  "127.0.0.1:${toString config.services.grafana.port}" = { };
                };
              };
              "prometheus" = {
                servers = {
                  "127.0.0.1:${toString config.services.prometheus.port}" = { };
                };
              };
              "loki" = {
                servers = {
                  "127.0.0.1:${
                    toString
                    config.services.loki.configuration.server.http_listen_port
                  }" = { };
                };
              };
              "promtail" = {
                servers = {
                  "127.0.0.1:${
                    toString
                    config.services.promtail.configuration.server.http_listen_port
                  }" = { };
                };
              };
            };
          };

          virtualisation.docker.rootless.daemon.settings = {
            "log-driver" = "json-file";
            "log-opts" = {
              "max-size" = "10m";
              "max-file" = "3";
            };
          };
        };
      };
    };
}
