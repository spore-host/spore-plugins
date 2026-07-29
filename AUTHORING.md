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

## How your spec appears in discovery

`spawn plugin search` and `spawn plugin info` read a generated index of this
registry (`index.json`), built from your `plugin.yaml` — so several fields are
user-facing before anyone installs anything:

| Spec field | Where it shows up |
|------------|-------------------|
| `description` | the one-line summary in `search`, and matched by search queries — write it for someone who doesn't know your tool exists |
| `version` | shown in both listings |
| `config.*` (`type`, `required`) | the config table in `info`, so users see what they must supply |
| `permissions.instance.root` | flagged as `[root]` in `search` results |
| `permissions.instance.ports` | listed in `info` |

Declaring `permissions` is what lets discovery warn about a plugin that needs
root or opens a port. A spec that omits the block shows nothing — reported as
"not declared" rather than "needs nothing", so declaring it accurately is how
users get an honest picture.

You never edit `index.json`: CI regenerates it from the specs when your PR
merges, and checks it on the PR.

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
