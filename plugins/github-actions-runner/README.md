# github-actions-runner

Registers your spawn instance as a **self-hosted GitHub Actions runner** for a
repo or org, so CI jobs targeting `runs-on: [self-hosted, spore]` execute on a
machine you sized (big CPU, GPU, lots of RAM).

## How it works (secret stays on your machine)

1. **Controller:** using your `GITHUB_TOKEN`, the plugin calls the GitHub API to
   mint a **short-lived (~1h) runner registration token**, and `push`es only that
   token to the instance. Your long-lived PAT never leaves your machine.
2. **Instance:** downloads the official `actions/runner`, registers with the
   pushed token (`config.sh` as the login user — it refuses root), and installs +
   starts a systemd service (`svc.sh`, runs as `ec2-user`).

No listening port — the runner long-polls GitHub outbound, so there's no
security-group concern.

## Setup

Create a PAT (classic: `repo` scope for a repo runner, or `admin:org` for an org
runner; or a fine-grained token / GitHub App with "Administration" read-write)
and export it:

```bash
export GITHUB_TOKEN=ghp_xxx
spawn plugin install github-actions-runner --instance <id> \
  --config scope=my-org/my-repo --config labels=spore,gpu
```

- `scope=owner/repo` → a **repo** runner; `scope=owner` → an **org** runner.

## Config

| Key | Default | Description |
|-----|---------|-------------|
| `scope` | *(required)* | `owner/repo` (repo runner) or `owner` (org runner). |
| `labels` | `spore` | Comma-separated runner labels. |
| `runner_version` | `2.319.1` | `actions/runner` release to install. |

## Why no automatic smoke

Registering a runner requires **your** `GITHUB_TOKEN` and a real repo/org, so this
ships **static-validated** with this recipe rather than an automated real-AWS
smoke. The mint→push→register→service flow mirrors the tailscale/globus plugins,
which are smoked.

## Notes

- On terminate, the plugin best-effort mints a remove-token; the runner also goes
  offline automatically when the instance dies, and GitHub prunes offline runners.
- Bump `runner_version` as new `actions/runner` releases land.
