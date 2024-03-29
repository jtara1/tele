# logs-app

automatically ingest logs from (rootless) docker and nginx access logs with dashboard configured


## Status

work in progress

I've made this for my specific setup with support for other people through several variables.

This was pulled out of another project of mine and needs to be re-tested.


## Setup

### Required Packages

remote host OS:
python, python module requests, docker, and promtail

local (development) OS:
ansible

### Create inventory.ini

you just need to define a few variables used in the playbook and this one way to do so

```shell
# writes to inventory.ini in $PWD
cat > inventory.ini << EOF
[my_host]
127.0.0.1 # your remote server IP, not loopback

[my_host:vars]
domain=example.com
ansible_user=my_user
EOF
```

think about the changes you need to make, especially to the several variables

### Publish

On host OS and its network, you should expose or redirect to its `localhost:3101`

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

Go to your remote host OS public IP that redirects to/exposes its localhost:3101
Login to the dashboard.

default Grafana dashboard (port 3101) login:
```text
username: admin
password: admin
```

The configuration adds a data source for Loki in Grafana. Just click Explore, select Loki, and start querying your logs.


## TODO

- [ ] fix apps-log promtail job and pipeline
- [ ] migrate everything to nixos config declaration
- [ ] nixos config services.promtail is broken? define systemd config
- [ ] symbolically link docker apps logs for readability (container name instead of container id, the long-hashes)
- [ ] .sh instead of ansible? Makefile instead of ansible?
- [ ] promtail to ingest logs for non-rootless (default) docker containers (I don't use this so this isn't for me)


## Notes

I was running the 3 in docker containers. Now, I'm running promtail directly on host OS.
Later, I may switch to running the 3 through nixos config.


## References

- [nix configs: grafana, prometheus, loki using journald as log driver](https://xeiaso.net/blog/prometheus-grafana-loki-nixos-2020-11-20/)
- [nix config: grafana](https://discourse.nixos.org/t/how-to-use-exported-grafana-dashboard/27739/2?u=jtara1)
- [pure nix config for all](https://gist.github.com/rickhull/895b0cb38fdd537c1078a858cf15d63e)