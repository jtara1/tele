# logs-app

automatically ingest logs from (rootless) docker and nginx access logs with dashboard configured


## Status

work in progress

assumptions for simplification:
 - docker containers run on same host
 - nginx runs on same host

## Setup

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

On host OS and its network, you should expose or redirect to its `localhost:3010`

### Security

Add security. Change grafana dashboard password. Allowlist your IP from which you're accessing it. etc


## Deploy

Run the ansible playbook from your local development OS

Something like
```shell
ansible-playbook -i inventory.ini --extra-vars logs_app_host=my_host logs.playbook.yml
```

### Run promtail

```shell
domain=example.com # change this
promtail -config.file="$HOME/$domain/logs-app/promtail-config.yml" -log.level=info
```


## Usage

Go to your remote host OS public IP that redirects to/exposes its localhost:3010
Login to the dashboard.

default Grafana dashboard (port 3010) login:
```text
username: admin
password: admin
```

The configuration adds a data source for Loki in Grafana. Just click Explore, select Loki, and start querying your logs.


## TODO

- [x] fix apps-log promtail job and pipeline
- [x] migrate everything to nixos config declaration
- [x] nixos config services.promtail
- [x] relabel docker apps logs for readability (container name instead of container id, the long-hashes)
- [x] ~~.sh instead of ansible? Makefile instead of ansible?~~ can import nix flake
- [ ] promtail to ingest logs for non-rootless (default) docker containers (I don't use this so this isn't for me)
- [ ] improve promtail job, docker
- [ ] re-add nginx access logs pipeline
- [x] prometheus for system monitoring and metrics
- [ ] alerts for core resources: cpu, storage, memory
- [ ] ingest logs from multiple virtual machines in dedicated logs-app server?
- [ ] fix and test the nginx config for local dev and for my server


## References

- [nix configs: grafana, prometheus, loki using journald as log driver](https://xeiaso.net/blog/prometheus-grafana-loki-nixos-2020-11-20/)
- [nix config: grafana](https://discourse.nixos.org/t/how-to-use-exported-grafana-dashboard/27739/2?u=jtara1)
- [pure nix config for all](https://gist.github.com/rickhull/895b0cb38fdd537c1078a858cf15d63e)