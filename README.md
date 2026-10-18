# spore-host/spore-plugins

Official plugin registry for [spawn](https://github.com/spore-host/spawn).

Plugins extend spawn with additional capabilities installed and managed on your EC2 instances.

**New to plugins? Read [CONCEPTS.md](CONCEPTS.md) first** — it explains the
controller/instance split and *why* each plugin needs certain setup, so the
per-plugin steps make sense.

## Finding a plugin

The authoritative, always-current list is the registry itself — ask spawn:

```bash
spawn plugin search              # every plugin here
spawn plugin search jupyter      # match names and descriptions
spawn plugin info tailscale      # version, config keys, whether it needs root
```

These read [`index.json`](index.json), a generated manifest of this registry's
contents that CI regenerates whenever a `plugin.yaml` changes (see
[Testing](#testing)). It is derived from the specs, never hand-edited, so it
can't drift from them the way a hand-kept table can. spawn caches it locally, so
search works offline and always tells you how old the listing is.

## Available plugins

Each plugin has its own `README.md` with a full setup walkthrough. Several need
a one-time setup first, usually a login or credential on your machine.

| Plugin | Description | Setup needed |
|--------|-------------|--------------|
| [cloudwatch-agent](plugins/cloudwatch-agent/README.md) | Host metrics and a log file to CloudWatch | launch the instance with an IAM role that can write to CloudWatch |
| [code-server](plugins/code-server/README.md) | VS Code in the browser | none |
| [docker](plugins/docker/README.md) | Docker engine, login user in the `docker` group | none |
| [github-actions-runner](plugins/github-actions-runner/README.md) | Self-hosted GitHub Actions runner | `GITHUB_TOKEN` exported; `curl`, `jq` |
| [globus-personal-endpoint](plugins/globus-personal-endpoint/README.md) | Globus Connect Personal endpoint for data transfer | `globus login` on your machine |
| [jupyterlab](plugins/jupyterlab/README.md) | Browser-based notebooks and Python | none |
| [mountpoint-s3](plugins/mountpoint-s3/README.md) | Mount an S3 bucket as a local filesystem | launch the instance with an IAM role that can access the bucket |
| [rclone](plugins/rclone/README.md) | Mount one of your rclone remotes | a remote set up with `rclone config`; `rclone`, `jq` |
| [rstudio-server](plugins/rstudio-server/README.md) | Browser-based R development environment | none |
| [spore-sync](plugins/spore-sync/README.md) | Live bidirectional directory sync via mutagen | `mutagen` installed locally |
| [tailscale](plugins/tailscale/README.md) | Join the instance to your Tailscale network | Tailscale OAuth client + ACL tag; `jq` |
| [vscode-tunnel](plugins/vscode-tunnel/README.md) | VS Code Remote Tunnel | a one-time device login on the instance after install |

## Installing a plugin

```bash
# From this registry by name: the plugin's latest signed release
# (see the plugin's README for its --config flags)
spawn plugin install tailscale --instance <id> --config tag=tag:spore

# Pin to a specific release (the tag is globus-personal-endpoint-v1.2.0)
spawn plugin install globus-personal-endpoint@v1.2.0 --instance <id>

# From any GitHub repo
spawn plugin install github:myorg/my-plugins/my-tool --instance <id>

# From a local file (development)
spawn plugin install ./my-plugin.yaml --instance <id>
```

`spawn plugin install` runs both the local (controller-side) and remote
(instance-side) halves of a plugin, waiting for the instance to be fully ready
first. See [CONCEPTS.md](CONCEPTS.md).

Preview what a plugin will run, without installing it or contacting an
instance, with `spawn plugin inspect <ref>` (or `spawn plugin install <ref>
--dry-run`). Plugins install on Linux spores only; spawn refuses a Windows spore.

## Contributing a plugin

See [AUTHORING.md](AUTHORING.md) for the plugin spec format and submission process.

## Testing

Three layers (see `.github/workflows/`):

- **Lint** (`lint.yml`) — runs on every push/PR. Downloads the released `spawn`
  binary and runs `spawn plugin validate --strict plugins/*/plugin.yaml`. This
  statically checks schema, semver, directory/name match, known
  step/condition/config types, and that every `{{ config.X }}` reference is
  declared; `--strict` also requires a `permissions:` block and checks it against
  the steps. `spawn` is the single source of truth for spec rules, so this never
  reimplements them.

  Validate locally before opening a PR:

  ```bash
  spawn plugin validate --strict plugins/<name>/plugin.yaml
  ```

- **Index** (`index.yml`) — runs when a `plugin.yaml` changes. Regenerates
  [`index.json`](index.json) with `spawn plugin gen-index` and commits it back on
  push to `main`; on a PR it *checks* the committed index matches the specs
  instead of pushing, so a spec change and its index entry are reviewed together.
  As with lint, `spawn` builds the index, so this never reimplements spec parsing.

  Regenerate locally if the check fails:

  ```bash
  spawn plugin gen-index plugins --source spore-host/spore-plugins \
    --generated-at "$(git log -1 --format=%cI -- 'plugins/*/plugin.yaml')" -o index.json
  ```

  The timestamp is keyed to the last spec commit, not to "now", so regenerating
  an unchanged registry is byte-identical and CI never commits churn.

- **Integration** (`integration.yml`) — gated (manual dispatch or nightly), not
  on PRs because it costs money. Launches a real EC2 instance per plugin in the
  dev account, installs the plugin, asserts it reaches a healthy status, then
  removes it and terminates the instance. Self-contained plugins
  (`rstudio-server`) run by default; plugins needing secrets (`tailscale`) run
  only when those secrets are configured; plugins needing controller-side
  tooling (`spore-sync`, `globus-personal-endpoint`) are not yet wired.

  Requires (configured out-of-band): an OIDC role in the dev account trusting
  this repo (`AWS_DEV_ROLE_ARN` secret), and optional per-plugin secrets
  (e.g. `TAILSCALE_AUTH_KEY`).

  It hasn't run since 2026-06-02, and its tailscale step passes an `auth_key`
  the current spec doesn't declare
  ([#29](https://github.com/spore-host/spore-plugins/issues/29)). Until that is
  fixed, no plugin is integration-tested by CI.

## License

Apache 2.0 — Copyright 2025-2026 Scott Friedman.
