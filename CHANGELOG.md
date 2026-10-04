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
