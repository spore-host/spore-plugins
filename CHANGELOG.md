# Changelog

All notable changes to the **spore.host plugin registry** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and each plugin adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## How versioning works here, and why this file looks different

This registry is **not tag-released as a whole**. Each plugin carries its own
`version:` in `plugins/<name>/plugin.yaml` and is tagged `<plugin>-vX.Y.Z`, so
there is no single repo version for a `## [X.Y.Z]` heading to refer to.

So released sections below are keyed by **plugin tag**, and `## [Unreleased]`
covers registry-level changes — tooling, `index.json` schema, docs, CI — plus any
plugin change not yet tagged. When you bump a plugin, add its entry under
`[Unreleased]` and move it to a `## [<plugin>-vX.Y.Z] - YYYY-MM-DD` section when
you tag.

## [Unreleased]

### Added

- `SECURITY.md`: report vulnerabilities privately through GitHub's private vulnerability reporting (the repository's Security tab), not public issues.

### Security

- **CI fails a plugin that installs what it has not verified** (#31, #33). The new
  `Artifact pins` job in `lint.yml` runs two checks.
  - `tests/artifact-pins.sh` is hermetic. It fails on a `sha256sum -c` whose
    failure is caught by `||` (how `mountpoint-s3` installed an unverified
    `.deb`), on a `fetch` step without `sha256` (spawn refuses one since
    spawn#838), and on a new `curl`/`wget`/`pip install` in a remote `run`
    step. The ten plugins that still download that way are listed in the script
    and tracked in #33. The list can only shrink.
  - `scripts/verify-artifact-pins.sh` downloads every pinned `fetch` artifact
    and checks its sha256 and size. For Mountpoint for Amazon S3 it also checks
    the `.asc` signature against AWS's release key, committed as
    `scripts/keys/mountpoint-s3.asc` and pinned by the fingerprints AWS
    publishes.
- `mountpoint-s3` v1.0.1 verifies its `.deb` (#31); see its
  [CHANGELOG](plugins/mountpoint-s3/CHANGELOG.md).

### Documentation

- `AUTHORING.md`: `sha256` is required on every `fetch` step (spawn#838), and
  `size` and `arch` are documented. Authors are told not to download in `run`
  steps, and how to pin one artifact per architecture.
- Plugin docs checked against spawn's spec parser (spore-host/spore-host#585).
  `AUTHORING.md`: a bare `spawn plugin install <name>` is the latest signed
  release, not `main`; nothing in CI requires `sha256` on `fetch` steps; the
  spec example no longer sets `required: true` with a `default` (which fails
  validation) and now includes `permissions:` (required by the `--strict` lint),
  `env_passthrough`, `capture`, `push`, `reconcile` and `as_user`; new sections
  list step fields, where each step type is allowed, and the template variables,
  including that values in `run` steps are shell-quoted. The README table lists
  all 12 plugins, the pinned example uses an existing release
  (`globus-personal-endpoint@v1.2.0`), lint is described as
  `validate --strict`, and the integration section says it hasn't run since
  2026-06-02 (#29).
  `CONCEPTS.md` says Tailscale removes an ephemeral node once it has been
  offline for a while. Per-plugin README fixes are in each plugin's changelog.
- `AUTHORING.md` has a "When each step runs" section (#27). `remote.stop` runs on
  `spawn plugin remove` only, not at instance stop, hibernate or terminate
  (spore-host/spawn#1037). The spec example no longer says `configure` "runs
  after each instance start": the remote steps run once at install, and re-run
  after a reboot only for a plugin declared at launch. `CONCEPTS.md`'s lifecycle
  section says the same, and the `tailscale` README no longer says
  `spawn plugin remove` stops `tailscaled` (its stop step is `tailscale down`).

## [2026-07-21] — first tagged release of all 12 plugins

Every plugin was tagged on the same day, so this is one dated section rather than
twelve. The versions differ because several plugins had development history
*before* the registry started tagging — `tailscale` at `v2.1.0` does not imply two
prior releases *of this registry*.

Reconstructed from the annotated tags and `plugin.yaml` rather than written at the
time; it records which version each plugin was first tagged at, not a per-change
history that was never captured.

| plugin | version |
|---|---|
| `cloudwatch-agent` | v1.0.0 |
| `code-server` | v1.0.0 |
| `docker` | v1.0.0 |
| `github-actions-runner` | v1.0.0 |
| `globus-personal-endpoint` | v1.2.0 |
| `jupyterlab` | v1.0.0 |
| `mountpoint-s3` | v1.0.0 |
| `rclone` | v1.0.0 |
| `rstudio-server` | v1.1.0 |
| `spore-sync` | v1.2.0 |
| `tailscale` | v2.1.0 |
| `vscode-tunnel` | v1.0.0 |

[Unreleased]: https://github.com/spore-host/spore-plugins/compare/vscode-tunnel-v1.0.0...HEAD
