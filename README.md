# logs-app

automatically ingest logs from (rootless) docker and nginx access logs with dashboard configured


## Setup

local-first development

assumptions for simplification:
- docker containers run on same host
- nginx runs on same host

promtail should safely fail for its respective scrape job if you're not running docker or nginx


### NixOS Flake

in your system `flake.nix` `inputs`, add
```text
    logs-app.url = "github:jtara1/logs-app";
```

in your `modules` or an `imports`, append
```text
    inputs.logs-app.nixosModules.default
```
where `inputs` is the 1st parameter in the function assigned to `outputs`.

### Publish

On host OS and its network, you should expose or redirect to its `localhost:3010`, 
grafana, the dashboard for querying and graphs


### Security

Add security. Change grafana dashboard password. Allowlist your IP from which you're accessing it. etc


## Usage

Go to the url for grafana, defaults to http://localhost:3010

default login:
```text
username: admin
password: admin
```

The configuration adds a data source for Loki in Grafana. Just click Explore, select Loki, and start querying your logs.


## TODO

- [x] migrate everything to nixos config declaration
- [x] nixos config services.promtail
- [x] relabel docker apps logs for readability (container name instead of container id, the long-hashes)
- [x] ~~.sh instead of ansible? Makefile instead of ansible?~~ can import nix flake
- [x] promtail to ingest logs for non-rootless (default) docker containers
- [ ] config to conditionally set docker deamon.json instead of docker rootless
- [x] improve promtail job, docker
- [x] re-add nginx access logs pipeline
- [x] prometheus for system monitoring and metrics
- [ ] alerts for core resources: cpu, storage, memory
- [ ] ingest logs from multiple virtual machines in dedicated logs-app server?
- [x] fix and test the nginx config for local dev and for my server
- [ ] refactor into nix module(s) to be more portable for non-flake NixOS users


## References

- [nix configs: grafana, prometheus, loki using journald as log driver](https://xeiaso.net/blog/prometheus-grafana-loki-nixos-2020-11-20/)
- [nix config: grafana](https://discourse.nixos.org/t/how-to-use-exported-grafana-dashboard/27739/2?u=jtara1)
- [pure nix config for all](https://gist.github.com/rickhull/895b0cb38fdd537c1078a858cf15d63e)