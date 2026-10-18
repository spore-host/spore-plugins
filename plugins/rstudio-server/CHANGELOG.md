# Changelog — `rstudio-server`

All notable changes to this plugin. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning: [SemVer 2.0.0](https://semver.org/spec/v2.0.0.html), per `CLAUDE.md`.

Bump `version:` in `plugin.yaml` in the **same PR** as any change to this plugin's
install script or interface — MAJOR for a breaking change to its inputs/behaviour,
MINOR for a backward-compatible feature, PATCH for a fix — and add the entry here.

## [Unreleased]

### Documentation

- The README's `launch.yaml` example uses `ref:` (spawn ignored `name:`, so
  nothing installed). It now says `r_version` has no effect, since the spec
  installs the distribution's R, and that the `url` output isn't reported yet
  (spore-host/spawn#1117).

## [v1.1.0] - 2026-07-21

First tagged release (`rstudio-server-v1.1.0`).

This file was added retroactively, so this section records **which version the
plugin was first tagged at**, not a per-change history — that was never captured.

The version is above `v1.0.0` because this plugin had development history before
the registry began tagging; it does not imply earlier *tagged* releases.

[Unreleased]: https://github.com/spore-host/spore-plugins/compare/rstudio-server-v1.1.0...HEAD
