# vscode-tunnel

Runs a **VS Code Remote Tunnel** on your spawn instance so you can attach to it
from desktop VS Code (the "Remote - Tunnels" extension) or from
[vscode.dev](https://vscode.dev) — full editor, terminal, and extensions, with
**no listening port and no security-group changes** (the tunnel is an outbound
relay to Microsoft's service, like Tailscale).

## How it works

The plugin installs the official VS Code CLI to `/usr/local/bin/code` and writes
a per-user systemd service (`vscode-tunnel`) that runs `code tunnel` as
`ec2-user`. Because a tunnel needs a **one-time interactive login**, the plugin
does **not** auto-start the service — you complete the login once, then start it.

## One-time setup (interactive login)

After installing the plugin, SSH to the instance and authenticate once:

```bash
# on the instance, as ec2-user:
code tunnel user login          # prints a code + URL; approve it in your browser
sudo systemctl enable --now vscode-tunnel
```

Then in desktop VS Code: **Remote-Tunnels: Connect to Tunnel…**, or open
`https://vscode.dev` and pick the tunnel. The `health` check reports `active`
once the service is running.

## Config

| Key | Default | Description |
|-----|---------|-------------|
| `name` | *(from hostname)* | Tunnel name shown in VS Code. |

## Install

```bash
spawn plugin install vscode-tunnel --instance <id> --config name=my-box
```

## Why no automatic smoke

This plugin requires an interactive GitHub/Microsoft device login that only you
can complete, so it ships **static-validated** (schema + permission consistency)
with this manual recipe rather than an automated real-AWS smoke. The install and
service-config steps are exercised; the login + tunnel are yours to drive.

## Notes

- No port is opened and no reconcile is needed — the tunnel reconnects outbound
  on its own after a stop/start.
- Prefer a browser IDE instead? See [`code-server`](../code-server/).
