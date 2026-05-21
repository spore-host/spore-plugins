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

## License

Apache 2.0 — Copyright 2025-2026 Scott Friedman.
