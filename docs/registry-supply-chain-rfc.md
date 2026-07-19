# RFC: Registry Supply-Chain — Signing, Pinning, and Permission Inspection

- **Status:** Draft (for discussion)
- **Tracking issue:** [spore-plugins#8](https://github.com/spore-host/spore-plugins/issues/8)
- **Related:** [spawn#387](https://github.com/spore-host/spawn/issues/387) (`plugin inspect`), [spawn#388](https://github.com/spore-host/spawn/issues/388) (`permissions:` block)

## Problem

Installing a plugin runs its author's code **on the user's machine** (local
provision steps) and, on the instance, **as root** (remote install/start steps).
Today the trust story is thin:

- `spawn plugin install github:org/repo/name` fetches `plugin.yaml` from
  `raw.githubusercontent.com` with only a "warning: unverified source" log for
  non-`spore-host` owners. Nothing is signed or checksummed.
- A bare `github:` ref (no `@version`) tracks the **default branch** — a moving
  target that can change under the user between inspect and install.
- Even for the official registry, a version resolves to a git ref; there is no
  attestation that the fetched bytes are the ones the maintainers published.

The reviewer's open questions, none currently answered: does a version resolve to
a tag/release/branch/manifest? are files checksummed? can a tag be moved? are
transitive downloads (a step's `fetch` URL) verified? is the resolved source
recorded on the instance? can the user inspect a plugin before it runs?

`spawn plugin inspect` / `--dry-run` (spawn#387, shipped) answers the *last* one —
you can now preview a plugin's steps, requested env, and declared `permissions:`
(spawn#388) before installing. This RFC covers the rest: **integrity and
provenance of the fetched definition itself.**

## Goals

1. A user can pin a plugin to an **immutable** reference and be sure the bytes
   don't change afterward.
2. The **official registry** publishes signed releases; `spawn` verifies the
   signature by default and records what it verified.
3. The **resolved source + digest** is recorded on the instance, so an installed
   plugin is auditable after the fact.
4. Clear, escalating trust tiers: official-signed > pinned-commit > branch-tracking
   > unpinned third-party.

Non-goals: sandboxing plugin execution (that's the `permissions:` declaration's
job, and it's advisory); a full package manager with dependency resolution.

## Proposed approach

### 1. Immutable pinning (client-side, no registry change)

- Teach the resolver to record the **resolved commit SHA** for any `github:` /
  official ref, even when the user gave a tag or branch, and surface it in
  `spawn plugin inspect` output and the on-instance install record.
- `spawn plugin install` writes the resolved `{owner, repo, ref, commit_sha,
  content_sha256}` into the local plugin record (already saved for deprovision)
  **and** an instance tag / spored plugin state, so an audit can answer "exactly
  which bytes were installed here."
- Warn (already partially done) and eventually require `--allow-unpinned` for a
  bare-branch third-party ref in non-interactive use.

### 2. Content checksums (registry + client)

- The registry publishes, per plugin release, a manifest of
  `plugin.yaml` sha256 (and any first-party assets). `spawn` verifies the fetched
  `plugin.yaml` against it.
- A step's `fetch` URL (a transitive download run on the instance) SHOULD carry an
  optional `sha256:` field in the spec; when present, spored verifies it after
  download. This closes the "unverified transitive download" gap and is a natural
  extension of the existing `fetch` step type.

### 3. Signed official releases

- Official-registry releases are signed (cosign/sigstore keyless, or a
  spore.host-held key consistent with the existing signing story for spore tools).
- `spawn` verifies the signature for `official` refs **by default**; failure is a
  hard error (with an explicit `--insecure`/`--no-verify` escape for local dev).
- Third-party (`github:` non-`spore-host`) refs remain unsigned but are clearly
  labeled as such in `inspect` and require pinning for unattended use.

### 4. Permission inspection (already specced)

`spawn plugin inspect` (spawn#387) renders the declared `permissions:` block
(spawn#388) before install. This RFC's job is to make the *definition being
inspected* trustworthy (signed + pinned), so "inspect then install" is a sound
workflow rather than a TOCTOU gap. Consider having the registry's CI **validate
that a plugin's declared `permissions` are consistent with its steps** (e.g. a
plugin declaring `instance.root=false` must not have non-`as_user` remote run
steps) so the declaration is enforced at publish time.

## Trust tiers (resulting UX)

| Ref form | Signed | Immutable | Default behavior |
|----------|--------|-----------|------------------|
| `name` / `name@vX` (official) | yes | via release + checksum | verify signature, record digest |
| `github:o/r/n@<commit>` | no | yes (commit) | record digest; warn unsigned |
| `github:o/r/n@<tag>` | no | tag can move | resolve+record commit; warn |
| `github:o/r/n` (bare) | no | no (branch) | warn; require `--allow-unpinned` unattended |

## Registry expansion (companion, separate track)

The reviewer noted the four current plugins prove the model but read as a demo.
Strong next candidates that each exercise a distinct capability shape (and would
benefit from the permission/signing story above): JupyterLab, code-server,
Docker/Podman, NVIDIA container toolkit, DCV, CloudWatch agent, Mountpoint-for-S3 /
rclone, VS Code tunnel, Slurm client, GitHub Actions runner. Tracked separately;
not gated on this RFC.

## Decisions needed

1. **Signing mechanism:** sigstore/cosign keyless vs. a spore.host-held key
   (consistency with how other spore tools are signed).
2. **Checksum manifest format & location:** a per-release `manifest.json` in the
   registry repo vs. GitHub release assets.
3. **Default strictness:** do we hard-fail unsigned *official* refs immediately,
   or ship verify-by-default with a deprecation window for unsigned?
4. **`fetch` checksum:** make `sha256:` on a `fetch` step optional (warn if
   missing) or eventually required for registry plugins.
5. **Where the on-instance install record lives:** local controller record only,
   an EC2 tag, spored plugin state, or all three.
6. **Publish-time permission/step consistency check:** in scope for this work or a
   follow-up in the registry CI?
