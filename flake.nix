{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs"; # unstable nixpkgs
  };

  outputs = { self, nixpkgs, ... } @ inputs: {
    nixosModules.default = { config, lib, ... }:
    let
      dockerLokiSettings = {
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
    in
    {
      options = {};
      config = lib.mkIf (config.virtualisation.docker.rootless.enable) {
        # enable docker loki plugin in docker daemon.json (settings); let user overwrite daemon.json in merge
        virtualisation.docker.rootless.daemon.settings = lib.mkMerge [
          dockerLokiSettings
          config.virtualisation.docker.rootless.customSettings or {}
        ];

        systemd.services = {
          dockerRootlessRestart = {
            wantedBy = [ "multi-user.target" ];
            after = [ "docker.service" ];
            requires = [ "docker.service" ];
            description = "Restart docker service after nixos-rebuild switch.";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = ''
                /bin/sh -c '
                  if ! systemctl --user is-active --quiet docker; then
                    echo systemd dockerRootlessRestart is restarting docker
                    systemctl --user restart docker
                  fi
                '
              '';
            };
          };

          dockerPluginLokiInstall = {
            wantedBy = [ "multi-user.target" ];
            after = [ "docker.service" ];
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
