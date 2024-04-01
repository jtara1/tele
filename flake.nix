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
              - nginx access logs
          '';

          enable = lib.mkOption {
            type = lib.types.bool;
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

#              limits_config = {
#                max_query_lookback = "7d";
#                max_query_length = "30d";
#              };

              schema_config = {
                configs = [{
                  from = "2020-01-01";
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

              scrape_configs = [
                # nginx access logs
                {
                  job_name = "nginx";
                  static_configs = [{
                    targets = ["localhost"];
                    labels = {
                      job = "nginx";
                      __path__ = "/var/log/nginx/access.log";
                    };
                  }];
                  pipeline_stages = [
                    {
                      regex = {
                        expression = ''(?P<remote_addr>[\w\.:\[\]]+) - (?P<remote_user>[^ ]*) \[(?P<time_local>[^\]]+)\] "(?P<request>[^"]*)" (?P<status>\d+) (?P<body_bytes_sent>\d+) "(?P<http_referer>[^"]*)" "(?P<http_user_agent>[^"]*)"'';
                      };
                    }
                    {
                      labels = { # consider removing unused labels
                        z_gate_remote_addr = "remote_addr";
                        z_gate_remote_user = "remote_user";
                        z_gate_time_local = "time_local";
                        z_gate_request = "request";
                        z_gate_status = "status";
                        z_gate_body_bytes_sent = "body_bytes_sent";
                        z_gate_http_referer = "http_referer";
                        z_gate_http_user_agent = "http_user_agent";
                      };
                    }
                  ];
                }
                # journal logs which includes docker container logs
                {
                  job_name = "journal";
                  journal = {
                    max_age = "12h";
                    labels = {
                      job = "journal";
                    };
                  };
                  relabel_configs = [ # explore journal log meta: $ journalctl CONTAINER_NAME=zealous_agnesi -o json --reverse --no-pager | head | jq
                    {
                      source_labels = [ "__journal__systemd_unit" ];
                      target_label = "unit";
                    }
                    {
                      source_labels = [ "__journal__hostname" ];
                      target_label = "hostname";
                    }
                    {
                      source_labels = [ "__journal_syslog_identifier" ];
                      target_label = "syslog_id";
                    }
                    {
                      source_labels = [ "__journal_container_name" ];
                      target_label = "container";
                    }
                  ];
                  pipeline_stages = [
                    # unwraps docker-wrapped container logs
                    { docker = { stop_grace_period = "1m"; }; } # process remaining logs after container exits
                    { # logs directly from container in docker journald MESSAGE meta
                      json = {
                        expressions = {
                          level = "level";
                        };
                      };
                    }
                    { # parsed from json pipeline stage
                      labels = { # some of the default labels from node.js pino logger,
                        level = "level";
                      };
                    }
                  ]; # other container logs can still be queried by property at query-time
                }
              ];
            };
            # extraFlags
          };

          # for file permissions to access the log file
          users.users.promtail.extraGroups = [ "nginx" ];

          # grafana: port 3010
          #
          services.grafana = {
            enable = true;
            settings = {
              server = {
                http_port = 3010;
                http_addr = "127.0.0.1";
                protocol = "http";
              };
              analytics.reporting_enabled = false;
            };
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
          # note: this is for use within your system nginx config
          #
          services.nginx = {
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
            log-driver = "journald";     # needs to be compatible with promtail scrape_config job
            log-opts = {
              tag = "{{.Name}}";         # set tag to container name, don't default to container id
              labels = "time,level,msg"; # default properties from node.js pino logger
            };
          };
        };
      };
    };
}
