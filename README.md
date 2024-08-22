# tele

[![FlakeHub](https://img.shields.io/endpoint?url=https://flakehub.com/f/jtara1/tele/badge)](https://flakehub.com/flake/jtara1/tele)

Dashboard to view system resources and query logs


## Features

- view timeseries graphs for: cpu, memory, storage, & networking
- receive email alerts when a resource (cpu, memory, or storage) is in high use
- ingest docker (rootless) container logs
- ingest nginx access logs
- query the logs

You're not required to use docker, nginx, or setup email (to receive alerts).


## Requirements

NixOS and Nix Flakes on remote host for usage. 


## Setup

assumptions for simplification:
- docker containers run on same host
- nginx runs on same host

promtail should safely fail for its respective scrape job if you're not running docker or nginx


### NixOS Flake

#### Import

in your system `flake.nix` `inputs`, add
```text
    tele.url = "github:jtara1/tele";
```

in your `modules` or an `imports`, append
```text
    inputs.tele.nixosModules.default
```
where `inputs` is the 1st parameter in the function assigned to `outputs`.

#### Configure

in a nix module, enable it with config such as
```text
  services.tele = {
    enable = true;
    email = {
      host = "mail.example.com:587";
      senderAddress = "admin@example.com";
      receiverAddress = "admin@example.com";
      secretsFilePath = /etc/tele/secrets.json;
    };
  };
```

`email` is optional and used for sending emails for notifications based on alert rules.

`secretsFilePath` should be a file path to a file containing:
```json
{
  "emailPlaintextPassword": "your-email-password"
}
```

### Publish

On host OS and its network, you should expose or redirect to its `http://localhost:3010`, 
grafana, the dashboard for querying and graphs

### Security

Add security. Change grafana dashboard password. Allowlist your IP from which you're accessing it. 
Encrypt the channel via TLS or other. etc.


## Usage

Go to the url for grafana, defaults to http://localhost:3010

default login:
```text
username: admin
password: admin
```

You can query logs, create visualizations, load a dashboard, or check alerts:
- Explore
- Dashboards
  - Node Exporter Full http://localhost:3010/d/rYdddlPWk/node-exporter-full?orgId=1&refresh=1m
- Alerting

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
- [x] 1st alerts rule for memory
- [x] alert notifications via SMTPS/email
- [x] alert rules for core resources: cpu, storage, memory
- [ ] ingest logs from multiple virtual machines in dedicated tele server?
- [x] fix and test the nginx config for local dev and for my server
- [ ] refactor into nix module(s) to be more portable for non-flake NixOS users
- [x] core health dashboard - pre-configured visualization for core resources
- [ ] improve management of email password for ease of secure and declarative use
- [x] publish to flakehub
- [ ] error: timestamp of a queried log is invalid
- [ ] alerts may need variable datasource uid


## References

- [How to Setup Prometheus, Grafana and Loki on NixOS](https://xeiaso.net/blog/prometheus-grafana-loki-nixos-2020-11-20/)
- [nix config: grafana](https://discourse.nixos.org/t/how-to-use-exported-grafana-dashboard/27739/2?u=jtara1)
- [pure nix config for all](https://gist.github.com/rickhull/895b0cb38fdd537c1078a858cf15d63e)
