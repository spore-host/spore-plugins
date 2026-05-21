# spore-host/spore-plugins

Official plugin registry for [spawn](https://github.com/spore-host/spawn).

Plugins extend spawn with additional capabilities — Tailscale networking, Globus data transfer, RStudio Server, and more.

## Installing a plugin

```bash
# Install from this registry by name
spawn plugin install tailscale

# Install a specific version
spawn plugin install globus-personal-endpoint@v1.2.0

# Install from any GitHub repo
spawn plugin install github:myorg/my-plugins/custom-tool

# Install from local file
spawn plugin install ./my-plugin.yaml
```

## Plugin structure

Each plugin is a directory containing a `plugin.yaml` spec:

```
plugins/
├── tailscale/
│   └── plugin.yaml
├── globus-personal-endpoint/
│   └── plugin.yaml
└── rstudio-server/
    └── plugin.yaml
```

## Contributing a plugin

See [AUTHORING.md](AUTHORING.md) for the plugin spec format and submission process.

## License

Apache 2.0
