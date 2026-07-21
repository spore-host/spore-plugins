# jupyterlab

Installs and starts **JupyterLab** on your spawn instance — browser-based
notebooks, a Python console, and a file browser on a machine sized for the work
(lots of RAM, many cores, or a GPU box).

## How it works

The plugin creates a Python virtualenv at `/opt/jupyterlab`, `pip install`s
JupyterLab into it, and runs it as a **systemd service** (`jupyterlab.service`)
as the instance's `ec2-user`. JupyterLab listens on **127.0.0.1:8888** by default.
A health check watches the service.

Everything runs **on the instance** — no controller-side setup and no secret to
pass. Works on RPM-based (Amazon Linux/RHEL/Rocky) and Debian/Ubuntu AMIs.

## Config

| Key | Default | Description |
|-----|---------|-------------|
| `port` | `8888` | Port JupyterLab listens on (loopback only). |
| `token` | *(empty)* | Auth token required in the URL. Empty **disables** token auth — safe only because the server binds to loopback and is reached over a tunnel. **Set your own for defense in depth.** |
| `notebook_dir` | `/home/ec2-user` | Directory JupyterLab opens in. |

## Install

At launch:

```yaml
# launch.yaml
plugins:
  - name: jupyterlab
    config:
      token: <choose-a-strong-token>
```

Or on a running instance:

```bash
spawn plugin install jupyterlab --instance <id> --config token=<strong-token>
```

## Connecting

JupyterLab binds to **loopback** (`127.0.0.1:8888`); the security group does not
open it to the internet. Reach it one of two safe ways:

**SSH tunnel (simplest):**

```bash
ssh -L 8888:localhost:8888 <instance>
# then open http://localhost:8888/  (append ?token=<token> if you set one)
```

**Tailscale:** add the [`tailscale`](../tailscale/) plugin, then — because the
server binds to loopback — either tunnel over SSH as above, or set
`--config port=8888` and bind to the Tailscale IP by editing the unit if you
want mesh-only access. The simplest secure default is the SSH tunnel.

## Notes

- If you leave `token` empty, anyone who reaches the port (i.e. anyone with the
  tunnel/SSH access) gets in without a prompt — fine for a single-user box, but
  set a token if others can SSH in.
- The first launch installs JupyterLab and its dependencies via pip, which can
  take a minute or two; the health check reports `active` once it's serving.
- Read a generated server URL/token on the instance with `jupyter server list`.
