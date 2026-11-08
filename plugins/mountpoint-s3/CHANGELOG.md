# Changelog — `mountpoint-s3`

All notable changes to this plugin. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning: [SemVer 2.0.0](https://semver.org/spec/v2.0.0.html), per `CLAUDE.md`.

Bump `version:` in `plugin.yaml` in the **same PR** as any change to this plugin's
install script or interface — MAJOR for a breaking change to its inputs/behaviour,
MINOR for a backward-compatible feature, PATCH for a fix — and add the entry here.

## [Unreleased]

## [v1.0.1] - 2026-11-08

### Security

- **The `.deb` is verified before install** (#31). On Debian and Ubuntu the plugin
  compared the `.deb` against the `.rpm`'s sha256. The check always failed, and
  `|| { echo note…; }` swallowed the failure, so `apt-get install` ran as root on a
  package nothing had verified. The packages are now downloaded by four `fetch`
  steps, the `.rpm` and `.deb` for x86_64 and arm64, each pinned by `sha256` and
  `size`. spored checks each download before anything uses it, and a mismatch
  deletes the file and fails the install. Every pin was taken from a package whose
  `.asc` verifies against AWS's Mountpoint release key (`673F E406 1506 BB46 9A0E
  F857 BE39 7A52 B086 DA5A`, the key that signed 1.19.0); CI re-checks the hashes,
  sizes and signatures. Because the hashes are in `plugin.yaml`, the release
  signature now covers the package too.
  - Mountpoint is still 1.19.0; nothing installed changes.
  - The download size changes. With spawn's `arch:` support (spawn#838), an
    instance fetches its own architecture's `.rpm` and `.deb`, about 25 MB. An
    earlier spawn ignores `arch:` and fetches all four, about 51 MB; each is still
    verified. It used to be one package, about 13 MB. The packages are written to
    `/opt/spore-plugins/mountpoint-s3/` and removed after install.
  - The check needs spored v0.86.0 (2026-07-20) or later, the first that checks a
    fetch step's `sha256`. An older spored downloads the packages without checking
    them.

## [v1.0.0] - 2026-07-21

First tagged release (`mountpoint-s3-v1.0.0`).

This file was added retroactively, so this section records **which version the
plugin was first tagged at**, not a per-change history — that was never captured.


[Unreleased]: https://github.com/spore-host/spore-plugins/compare/mountpoint-s3-v1.0.1...HEAD
[v1.0.1]: https://github.com/spore-host/spore-plugins/compare/mountpoint-s3-v1.0.0...mountpoint-s3-v1.0.1
