# spore-host/spore-plugins

Official plugin registry for [spawn](https://github.com/spore-host/spawn).

Plugins extend spawn with additional capabilities installed and managed on your EC2 instances.

**New to plugins? Read [CONCEPTS.md](CONCEPTS.md) first** — it explains the
controller/instance split and *why* each plugin needs certain setup, so the
per-plugin steps make sense.

## Available plugins

Each plugin has its own `README.md` with a full setup walkthrough — most need a
one-time local setup (a login or credential on your machine) before first use.

| Plugin | Description | Setup needed |
|--------|-------------|--------------|
| [tailscale](plugins/tailscale/README.md) | Join the instance to your Tailscale network | Tailscale OAuth client + ACL tag; `jq` |
| [globus-personal-endpoint](plugins/globus-personal-endpoint/README.md) | Globus Connect Personal endpoint for data transfer | `globus login` on your machine |
| [spore-sync](plugins/spore-sync/README.md) | Live bidirectional directory sync via mutagen | `mutagen` installed locally |
| [rstudio-server](plugins/rstudio-server/) | Browser-based R development environment | none |

## Installing a plugin

```bash
# From this registry by name (see the plugin's README for its --config flags)
spawn plugin install tailscale --instance <id> --config tag=tag:spore

# Pin to a specific version
spawn plugin install globus-personal-endpoint@v1.0.0 --instance <id>

# From any GitHub repo
spawn plugin install github:myorg/my-plugins/my-tool --instance <id>

# From a local file (development)
spawn plugin install ./my-plugin.yaml --instance <id>
```

`spawn plugin install` runs both the local (controller-side) and remote
(instance-side) halves of a plugin, waiting for the instance to be fully ready
first. See [CONCEPTS.md](CONCEPTS.md).

## Contributing a plugin

See [AUTHORING.md](AUTHORING.md) for the plugin spec format and submission process.

## Testing

Two layers (see `.github/workflows/`):

- **Lint** (`lint.yml`) — runs on every push/PR. Downloads the released `spawn`
  binary and runs `spawn plugin validate plugins/*/plugin.yaml`. This statically
  checks schema, semver, directory/name match, known step/condition/config
  types, and that every `{{ config.X }}` reference is declared. `spawn` is the
  single source of truth for spec rules, so this never reimplements them.

  Validate locally before opening a PR:

  ```bash
  spawn plugin validate plugins/<name>/plugin.yaml
  ```

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

## License

Apache 2.0 — Copyright 2025-2026 Scott Friedman.
