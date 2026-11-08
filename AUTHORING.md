# Writing a spore-host plugin

A plugin is a `plugin.yaml` file that declares lifecycle steps run on the instance and/or the controller machine.

## Spec format

```yaml
name: my-plugin            # must match the directory name
version: v1.0.0            # semver
description: "..."         # required; shown by `spawn plugin search`
author: spore-host         # metadata only; spawn ignores it
license: Apache-2.0        # metadata only; spawn ignores it

# Declared capability surface. Required by `spawn plugin validate --strict`,
# which the registry's lint CI runs, so every registry plugin has one.
permissions:
  controller:
    network: true          # local steps make network calls
    env: [MY_TOOL_TOKEN]   # must include everything in local.env_passthrough
    commands: [curl, jq]   # executables expected on your PATH
  instance:
    root: true             # some remote step runs as root
    network: true          # remote steps download things
    ports: [8080]          # TCP ports the plugin listens on
    files: [/opt/my-tool]  # notable paths it creates

# Configuration parameters exposed via --config key=value
config:
  my_param:
    type: string           # string | int | bool
    required: false        # required: true can't also have a default
    default: "default"
  my_secret_name:
    type: string
    required: true

# Pre-flight checks before install
conditions:
  local:
    - type: command
      run: command -v jq >/dev/null
      message: "jq must be installed locally"
  remote:
    - type: platform
      os: linux

# Steps run on the controller machine
local:
  env_passthrough:         # the only controller env vars local steps can see
    - MY_TOOL_TOKEN        # (besides PATH and HOME)
  provision:               # runs on `spawn plugin install`, before the remote steps
    - type: run
      run: |
        NAME={{ config.my_secret_name }}
        curl -sf -H "Authorization: Bearer $MY_TOOL_TOKEN" \
          "https://api.example.com/keys?name=$NAME"
      capture:             # stdout must be JSON; the value becomes outputs.api_key
        api_key: key
    - type: push           # deliver it to the instance as pushed.api_key
      key: api_key
      value: "{{ outputs.api_key }}"
  reconcile:               # runs after `spawn start` gives the instance a new IP
    - type: run
      run: my-local-sync --host {{ instance.ip }}
  deprovision:             # runs on `spawn plugin remove` and `spawn terminate`
    - type: run
      run: cleanup-command

# Steps run on the remote EC2 instance
remote:
  install:                 # install → configure → start run once, at install
    - type: run
      run: |
        curl -fsSL https://example.com/install.sh | sh
  configure:               # after install (re-run on boot only if declared at launch)
    - type: run
      run: |
        KEY={{ pushed.api_key }}
        my-tool configure --key "$KEY" --param {{ config.my_param }}
    - type: run
      as_user: true        # run as the instance's login user, not root
      run: my-tool init-user
  start:
    - type: run
      run: systemctl enable --now my-service
  stop:                    # runs on `spawn plugin remove` only, never at instance stop
    - type: run
      run: systemctl stop my-service
  health:
    interval: 30s
    steps:
      - type: run
        run: systemctl is-active my-service

# Names of the values the plugin produces (shown by `spawn plugin inspect`)
outputs:
  api_key:
    source: local_capture  # local_capture | pushed
```

spawn doesn't read a `description` under `config.<name>` or `outputs.<name>`.
The registry's specs keep one under `config` as a note for readers, but
nothing displays it. Output values are not reported after install yet
([spore-host/spawn#1117](https://github.com/spore-host/spawn/issues/1117)), so
if a user needs a value, print it from a step or explain in the README how to
read it.

## When each step runs

| Steps | Run |
|-------|-----|
| `local.provision` | On `spawn plugin install`, on your machine, before any remote step. |
| `remote.install` → `configure` → `start` | Once, at install, in that order. See below for what happens after a reboot. |
| `remote.health` | Every `interval` while spored is running the plugin. |
| `local.reconcile` | After `spawn start`, on your machine, with the instance's new public IP. |
| `remote.stop` | On `spawn plugin remove` only. Not when the instance stops, hibernates or terminates. |
| `local.deprovision` | On `spawn plugin remove` and `spawn terminate`, on your machine. |

**After a stop/start or reboot**, what re-runs depends on how the plugin was
installed:

- **`spawn plugin install`** — nothing re-runs `install`, `configure` or
  `start`. The service has to come back on its own, so enable it at install
  (`systemctl enable --now my-service`, as the `tailscale` plugin does), and keep
  any state `configure` writes on disk.
- **Declared at launch (`spawn launch --plugin`)** — spored re-installs the
  plugin, running `install` → `configure` → `start` again, whenever it starts and
  finds the plugin not running. spored marks its plugins stopped when it shuts
  down, so in practice that is every boot and every spored restart. Write these
  steps so they are safe to run again on an instance where they already ran.

**`remote.stop` is the undo of an install.** `spawn plugin remove` runs it on the
instance, with the plugin's config and pushed values, before spored forgets the
plugin. A failing stop step does not block the removal: the plugin is removed
anyway, and spawn warns that what it started may still be running.

It does **not** run when the instance stops, hibernates or terminates, so don't
rely on it for shutdown-time work. The OS shutdown stops services anyway (a
hibernate freezes and resumes them), and nothing re-runs `remote.start` when the
instance comes back, so a stop step at shutdown would outlast it: the `tailscale`
plugin's stop is `tailscale down`, which would keep the node off your tailnet
after the next `spawn start`.

`remote.stop` runs on remove from spawn with
[spore-host/spawn#1037](https://github.com/spore-host/spawn/pull/1037). A plugin
installed by an older spored has no stop steps on record, so removing it runs
none.

## Step types

| Type | Where | Description |
|------|-------|-------------|
| `run` | local and remote | Execute a shell command with `sh -c` |
| `fetch` | remote | Download a file to the instance (`url` → `dest`, required `sha256`) |
| `extract` | remote | Extract an archive (`src` → `dest`) |
| `push` | `local.provision` | Push a value (`key`, `value`) to the instance |

`spawn plugin validate` rejects `fetch` and `extract` in `local`, and `push` in
`remote`. `local.deprovision` and `local.reconcile` run `run` steps only: spawn
fails on a `push` there at run time, though `validate` doesn't catch it.

### Step fields

| Field | Applies to | Description |
|-------|------------|-------------|
| `run` | `run` | The shell command. |
| `url`, `dest`, `sha256` | `fetch` | Download source, destination, and expected checksum (required). |
| `size` | `fetch` | Optional exact byte length of the download. |
| `arch` | `fetch` | Optional: fetch only on `x86_64` (or `amd64`) or `arm64` (or `aarch64`) instances. |
| `src`, `dest` | `extract` | Archive and target directory. |
| `key`, `value` | `push` | The name the instance reads it under (`{{ pushed.<key> }}`) and the value, usually `{{ outputs.<name> }}`. |
| `capture` | local `run` in `provision` | Map of `name: path`. The step's stdout must be JSON; `path` is a dotted key path (`key`, or `.data.id` for nested keys). Each value becomes `{{ outputs.<name> }}`. |
| `env` | `run` | Extra environment variables for the step. Values are not templated. |
| `as_user` | remote `run` | Run as the instance's login user (via `su -`) instead of root. |
| `background` | remote `run` | Start the command detached (`nohup`) and return at once. |

`capture` on a remote step, and `as_user` or `background` on a local step, are
ignored.

## Template variables

Write references as `{{ namespace.key }}`. Any other form, such as Go's
`{{ .Config.key }}`, fails `spawn plugin validate`, and so does a reference to a
config key the spec doesn't declare.

| Variable | Value | Available in |
|----------|-------|--------------|
| `{{ instance.id }}` | EC2 instance ID | local and remote |
| `{{ instance.name }}` | The instance's Name tag | local and remote |
| `{{ instance.ip }}` | Public IP | local and remote |
| `{{ instance.login_user }}` | The instance's login user, the one `as_user` steps run as | remote |
| `{{ config.<key> }}` | A config value (or its default) | local and remote |
| `{{ outputs.<name> }}` | A value captured by an earlier local step | local |
| `{{ pushed.<key> }}` | A value delivered by a `push` step | remote |

Use `{{ instance.login_user }}` rather than hardcoding `ec2-user`: spawn creates
a login user matching your own name (see [CONCEPTS.md](CONCEPTS.md)).

**Values in `run` steps are shell-quoted.** In a `run` step or a `command`
condition, each substituted value is wrapped in single quotes, so a value can't
inject shell syntax. That is right for a bare argument or an assignment, but it
puts literal quotes inside a larger string (`"spore-{{ instance.id }}"` becomes
`"spore-'i-abc'"`). Assign the value to a shell variable first:

```yaml
    - type: run
      run: |
        NAME={{ instance.id }}
        DESC="spore-$NAME"
```

`url`, `dest`, `src` and push `value` are substituted without quoting.

### Verifying a `fetch` download

Every `fetch` step must declare `sha256:`, the expected checksum of the
downloaded bytes as a 64-char lowercase hex digest. spored hashes the download
as it writes it, and on a mismatch it deletes the file and fails the install,
so no later step can use a tampered or corrupted download. The release
signature covers `plugin.yaml`, so a pinned `sha256:` puts the download under
that signature too. Since spawn#838, spawn refuses a `fetch` step with no
`sha256:`: `spawn plugin validate` reports it, and both `spawn plugin install`
and spored refuse the plugin before any step runs.

```yaml
    - type: fetch
      url: https://example.com/tool-v1.2.3-linux-amd64.tar.gz
      dest: /opt/spore-plugins/tool/tool.tar.gz
      sha256: 9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08
      size: 1048576
```

Compute it with `sha256sum <file>` (or `shasum -a 256 <file>`). Pin a specific
released asset URL, not a "latest" redirect: a "latest" URL serves different
bytes after every upstream release, and the install then fails. Where the
upstream signs its releases, verify the signature on the file you take the pin
from. `size:` is optional; when set, spored refuses a download of any other
length.

**One artifact per architecture.** A step with `arch:` runs only on instances of
that architecture, so each architecture can have its own artifact and its own
`sha256:`. Give each one its own `dest`, and choose between them in a later
`run` step. `mountpoint-s3` does this, with four pinned packages (`.rpm` and
`.deb` for each architecture). spawn releases that predate `arch:` ignore it and
fetch every listed artifact, each still checked against its own `sha256:`.

**Don't download in a `run` step.** A `curl`, `wget` or `pip install` inside a
`run` step's script is opaque to spawn, and nothing verifies what it fetches.
CI (`tests/artifact-pins.sh`) fails a new plugin that does this. It also fails
a `sha256sum -c` whose failure is caught by `||`. The plugins that still
download in a `run` step are listed in that script and tracked in #33.
`scripts/verify-artifact-pins.sh` downloads every pinned artifact in CI and
checks its sha256 and size, plus the upstream's signature where the script
knows how (Mountpoint for Amazon S3).

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
2. Create `plugins/<your-plugin-name>/plugin.yaml`, a `README.md`, and a
   `CHANGELOG.md`
3. Check it offline with `spawn plugin validate --strict
   plugins/<your-plugin-name>/plugin.yaml` (what lint CI runs) and
   `spawn plugin inspect ./plugins/<your-plugin-name>/plugin.yaml`
4. Test it with `spawn plugin install ./plugins/<your-plugin-name>/plugin.yaml
   --instance <name>`. The registry's integration workflow isn't running today
   ([#29](https://github.com/spore-host/spore-plugins/issues/29)), so this is
   the only real-instance test your plugin gets
5. Open a pull request

## Releasing a versioned plugin

Users install an official plugin from a release, never from `main`: a bare
`spawn plugin install <name>` resolves to the plugin's latest release, and
spawn refuses (unless `--insecure`) when there is no release or it can't look
one up. A change merged to `main` reaches users only when you tag it. To
publish an **immutable, signed** version:

1. Set the plugin's `version:` in `plugin.yaml` (SemVer, e.g. `v1.2.0`) and merge
   it to `main`.
2. Tag the release **`<name>-<version>`** (e.g. `tailscale-v1.2.0`) and push the
   tag. The `Release plugin` workflow verifies the tag's version matches the
   `plugin.yaml`, generates `manifest.json` with `spawn plugin manifest`, signs
   it keyless with cosign, and publishes a GitHub Release carrying the manifest
   and its Sigstore bundle (`manifest.json.sigstore.json`).
3. `spawn plugin install <name>` now picks up the new release, and
   `spawn plugin install <name>@<version>` pins it. Either way spawn fetches
   `plugin.yaml` at the tag, verifies its sha256 against the release's
   `manifest.json`, and verifies the signature came from this repo's
   `release.yml`. A missing manifest or signature, a mismatch, or a signature
   from any other identity is a hard failure.

The tag's version and the `plugin.yaml` `version:` must agree — CI rejects the
release otherwise, so the released bytes and the tag can never disagree.
