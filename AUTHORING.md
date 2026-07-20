# Writing a spore-host plugin

A plugin is a `plugin.yaml` file that declares lifecycle steps run on the instance and/or the controller machine.

## Spec format

```yaml
name: my-plugin            # kebab-case, must match directory name
version: v1.0.0            # semver
description: "..."
author: spore-host         # GitHub org or username
license: Apache-2.0        # SPDX identifier

# Configuration parameters exposed via --config key=value
config:
  my_param:
    type: string           # string | int | bool
    required: true
    default: "default"
    description: "..."

# Pre-flight checks before install
conditions:
  local:
    - type: command
      run: my-tool --version
      message: "my-tool must be installed locally"
  remote:
    - type: platform
      os: linux

# Steps run on the controller machine
local:
  provision:               # runs during plugin install
    - type: run
      run: |
        some-local-command
  deprovision:             # runs during plugin remove
    - type: run
      run: cleanup-command

# Steps run on the remote EC2 instance
remote:
  install:                 # one-time install
    - type: run
      run: |
        curl -fsSL https://example.com/install.sh | sh
  configure:               # runs after each instance start
    - type: run
      run: my-tool configure
  start:
    - type: run
      run: systemctl start my-service
  stop:
    - type: run
      run: systemctl stop my-service
  health:
    interval: 30s
    steps:
      - type: run
        run: systemctl is-active my-service

# Values captured during lifecycle and exposed to other steps
outputs:
  my_output:
    description: "..."
```

## Step types

| Type | Description |
|------|-------------|
| `run` | Execute a shell command |
| `fetch` | Download a file to the instance |
| `extract` | Extract an archive |
| `push` | Push a local value to the instance |

## Submitting

1. Fork this repo
2. Create `plugins/<your-plugin-name>/plugin.yaml`
3. Test with `spawn plugin install ./plugins/my-plugin/plugin.yaml --instance <name>`
4. Open a pull request

## Releasing a versioned plugin

Bare `spawn plugin install <name>` tracks `main` (unversioned, unverified). To
publish an **immutable, checksum-verified** version:

1. Set the plugin's `version:` in `plugin.yaml` (SemVer, e.g. `v1.2.0`) and merge
   it to `main`.
2. Tag the release **`<name>-<version>`** (e.g. `tailscale-v1.2.0`) and push the
   tag. The `Release plugin` workflow verifies the tag's version matches the
   `plugin.yaml`, generates `manifest.json` with `spawn plugin manifest`, and
   publishes a GitHub Release carrying that manifest as an asset.
3. Users then install `spawn plugin install <name>@<version>` — spawn fetches
   `plugin.yaml` at the tag and verifies its sha256 against the release's
   `manifest.json`. A missing manifest or a mismatch is a hard failure.

The tag's version and the `plugin.yaml` `version:` must agree — CI rejects the
release otherwise, so the released bytes and the tag can never disagree.
