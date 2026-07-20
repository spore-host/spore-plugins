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
| `fetch` | Download a file to the instance (`url` → `dest`) |
| `extract` | Extract an archive |
| `push` | Push a local value to the instance |

### Verifying a `fetch` download

A `fetch` step may declare an optional `sha256:` — the expected checksum of the
downloaded bytes as a 64-char lowercase hex digest. When set, spored verifies the
download after fetching and fails the install (removing the file) on a mismatch,
so a tampered or corrupted transitive download can't be installed:

```yaml
    - type: fetch
      url: https://example.com/tool-v1.2.3-linux-amd64.tar.gz
      dest: /tmp/tool.tar.gz
      sha256: 9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08
```

Compute it locally with `sha256sum <file>` (or `shasum -a 256 <file>`), pinning a
specific released asset URL rather than a "latest" redirect. `sha256:` is
optional for third-party plugins but **required on `fetch` steps of official
registry plugins** (enforced by the registry's publish-time checks).

## Submitting

1. Fork this repo
2. Create `plugins/<your-plugin-name>/plugin.yaml`
3. Test with `spawn plugin install ./plugins/my-plugin/plugin.yaml --instance <name>`
4. Open a pull request
