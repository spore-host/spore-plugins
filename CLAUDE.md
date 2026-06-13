# CLAUDE.md — spore-plugins

The official plugin registry for [spawn](https://github.com/spore-host/spawn).
Each plugin lives under `plugins/<name>/` with a `plugin.yaml` manifest. Part of
the spore.host suite.

## Versioning & changelog (required)

The spore.host-wide policy is **[Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html)**
+ **[Keep a Changelog](https://keepachangelog.com/en/1.1.0/)**. This repo is a
**registry, not a single released artifact**, so the policy applies **per
plugin**:

- Each plugin's `plugin.yaml` carries its own `version: vX.Y.Z`. **Bump it by
  SemVer** on every change to that plugin's install script or interface — MAJOR
  for a breaking change to its inputs/behavior, MINOR for a backward-compatible
  feature, PATCH for a fix.
- Keep a per-plugin changelog: a `## [Unreleased]` → dated-version section either
  in the plugin's `CHANGELOG.md` or a `changelog:` block in its `plugin.yaml`.
  Describe the user-visible effect; reference the issue/PR. Do it in the same PR
  as the change.
- The registry itself isn't tag-released; there's no repo-wide version. A
  top-level `CHANGELOG.md` (registry-level changes: plugins added/removed,
  schema changes) is optional but welcome.

See `AUTHORING.md` for the plugin manifest format.
