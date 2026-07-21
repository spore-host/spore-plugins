# docker

Installs the **Docker engine** on your spawn instance and enables it as a
persistent service, so an interactive or long-lived box can build and run
containers.

## How it works

The plugin installs docker (from the AL2023/Amazon Linux repos, or the official
convenience script on Debian/Ubuntu), enables and starts the `docker` service,
and adds `ec2-user` to the `docker` group so you can run `docker` without `sudo`.
A health check runs `docker info`.

Everything runs **on the instance** — no controller-side setup, no config.

## When to use this vs. `task run --container`

- **This plugin** — you want Docker *always available* on a persistent instance
  you SSH into and work on interactively (build images, run `docker compose`,
  etc.).
- **`spawn task run --container <image>`** — you want to run a single containerized
  job on an ephemeral instance; spawn installs docker on demand and tears the
  instance down after. No plugin needed.

## Install

At launch:

```yaml
# launch.yaml
plugins:
  - name: docker
```

Or on a running instance:

```bash
spawn plugin install docker --instance <id>
```

## Notes

- The `ec2-user` docker-group membership takes effect on your **next login** —
  reconnect (or run `newgrp docker`) after install to use docker without sudo.
- For GPU containers, launch on a GPU instance type (spawn auto-selects an NVIDIA
  driver AMI) — the driver + container toolkit come from that AMI; then
  `docker run --gpus all …` works.
