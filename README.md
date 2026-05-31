# spore-host/spore-plugins

Official plugin registry for [spawn](https://github.com/spore-host/spawn).

Plugins extend spawn with additional capabilities installed and managed on your EC2 instances.

## Available plugins

| Plugin | Description | Install |
|--------|-------------|---------|
| [tailscale](plugins/tailscale/) | Private networking via Tailscale WireGuard mesh | `spawn plugin install tailscale` |
| [globus-personal-endpoint](plugins/globus-personal-endpoint/) | High-speed data transfer via Globus Connect Personal | `spawn plugin install globus-personal-endpoint` |
| [rstudio-server](plugins/rstudio-server/) | Browser-based R development environment | `spawn plugin install rstudio-server` |
| [spore-sync](plugins/spore-sync/) | Live bidirectional directory sync with mutagen | `spawn plugin install spore-sync` |

## Installing a plugin

```bash
# Install from this registry by name
spawn plugin install tailscale --config auth_key=tskey-auth-...

# Pin to a specific version
spawn plugin install globus-personal-endpoint@v1.0.0

# Install from any GitHub repo
spawn plugin install github:myorg/my-plugins/my-tool

# Install from a local file (development)
spawn plugin install ./my-plugin.yaml
```

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
