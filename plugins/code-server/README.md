# code-server

Installs and starts **code-server** — a full VS Code IDE served in your browser —
on your spawn instance, so you get the VS Code editor, terminal, and extensions
on a machine sized for the work.

## How it works

The plugin runs the official code-server installer, writes a
`~/.config/code-server/config.yaml` for `ec2-user` with password auth, and starts
the `code-server@ec2-user` systemd service. code-server listens on
**127.0.0.1:8080** by default. A health check watches the service.

Everything runs **on the instance** — no controller-side setup. Works on RPM-based
(Amazon Linux/RHEL/Rocky) and Debian/Ubuntu AMIs, x86_64 and arm64.

## Config

| Key | Default | Description |
|-----|---------|-------------|
| `port` | `8080` | Port code-server listens on (loopback only). |
| `password` | `spore` | Password for the web UI. **Set your own.** |

## Install

At launch:

```yaml
# launch.yaml
plugins:
  - name: code-server
    config:
      password: <choose-a-strong-password>
```

Or on a running instance:

```bash
spawn plugin install code-server --instance <id> --config password=<strong-password>
```

## Connecting

code-server binds to **loopback** (`127.0.0.1:8080`); the security group does not
open it to the internet. Reach it one of two safe ways:

**SSH tunnel (simplest):**

```bash
ssh -L 8080:localhost:8080 <instance>
# then open http://localhost:8080/ and log in with your password
```

**Tailscale:** add the [`tailscale`](../tailscale/) plugin and tunnel over SSH, or
adjust `bind-addr` to the Tailscale IP for mesh-only access. The simplest secure
default is the SSH tunnel.

## Notes

- The installer sets up a per-user systemd template unit
  (`code-server@ec2-user`); the plugin enables it for `ec2-user`.
- If you prefer VS Code's own Remote Tunnels instead of a browser IDE, see the
  [`vscode-tunnel`](../vscode-tunnel/) plugin, which needs no port at all.
