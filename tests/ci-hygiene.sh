#!/usr/bin/env bash
# Asserts on repo wiring rather than on plugin specs.
#
# Wiring is what rots: reverting a pin to `@v6` or deleting the Dependabot entry
# is a one-line change whose absence is completely silent — nothing fails, CI's
# supply chain just quietly goes back to being mutable. This makes that fail. (#19)
#
# It matters more here than in most repos. release.yml holds `id-token: write` and
# signs plugin manifests keyless with cosign; `spawn` trusts a manifest by pinning
# the Fulcio cert identity to this repo + workflow, so whatever runs in that job
# can sign as us — and being keyless, there is no key to rotate afterward.
# index.yml commits index.json back to main, and integration.yml mints dev-account
# AWS credentials. Those are the jobs whose refs were unpinned.
#
# Shell rather than a test framework because this repo has neither: the plugins are
# YAML specs and CI drives a downloaded `spawn` binary. Two files are read; nothing
# is installed.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOWS="$REPO/.github/workflows"
DEPENDABOT="$REPO/.github/dependabot.yml"

fail() { echo "CI HYGIENE FAILED: $*" >&2; exit 1; }

# --- 1. Every action ref must be a full 40-hex commit SHA with a `# vX.Y.Z` note.
#
# A tag is mutable: `@v6` means "whatever v6 points at when the job runs".
# actions/checkout@v6 really did move (df4cb1c 2026-06-02 -> d23441a 2026-07-16)
# and configure-aws-credentials@v6 moved v6.2.2 -> v6.2.3, both with no signal to
# consumers. The version comment is required too — a bare SHA is unreadable, and
# the version is what makes a bump reviewable.
#
# Match whole lines, not a `-o` extraction: the SHA and its `# vX.Y.Z` comment have
# to be checked together, and cutting the line at the SHA would discard the very
# comment being asserted. `[[:space:]]` not `\s` — `\s` is a GNU extension that BSD
# grep/sed silently fail to match, which would make this check pass by accident.
refs=$(grep -rhE '^[[:space:]]*(- )?uses:' "$WORKFLOWS" \
  | sed -E 's/^[[:space:]]*(- )?uses:[[:space:]]*//' || true)

# Anti-vacuous: if the parser stops matching, this script would pass forever.
[ -n "$refs" ] || fail "no \`uses:\` refs found under $WORKFLOWS — this check is asserting nothing"

unpinned=""
actions=""
while IFS= read -r ref; do
  [ -n "$ref" ] || continue
  case "$ref" in ./*) continue ;; esac  # local path, not a registry ref
  # The comment must be an EXACT vX.Y.Z, not a bare `# v6`. A bare major cannot be
  # checked against the SHA and can silently misstate what CI runs: Dependabot bumped
  # nf-spawn's checkout pin to a v7.0.1 SHA while leaving the comment reading `# v6`,
  # and the older `v?[0-9]` form of this pattern passed it. A wrong label is worse than
  # a missing one — it makes a major-version jump read as a routine same-line bump.
  # scripts/verify-pins.sh checks comment-against-tag for real; that needs the network,
  # so it stays out of this (hermetic) script.
  grep -qE '^[^@[:space:]]+@[0-9a-f]{40}[[:space:]]+#[[:space:]]*v[0-9]+\.[0-9]+\.[0-9]+[[:space:]]*$' <<<"$ref" \
    || unpinned+="    $ref"$'\n'
  # owner/name, for the coverage check below
  name="${ref%%@*}"
  grep -qxF "$name" <<<"$actions" || actions+="$name"$'\n'
done <<<"$refs"

[ -z "$unpinned" ] || fail "actions not pinned to a commit SHA with a version comment:
$unpinned
A tag or branch is mutable, so the code CI runs can change with no commit here.
release.yml signs plugin manifests with cosign under this repo's OIDC identity —
an unpinned ref there can sign as us. Use:
    uses: owner/action@<40-hex-sha> # vX.Y.Z"

# --- 2. Something must bump those pins.
#
# A SHA never moves, including past a security fix, so pinning without Dependabot
# just trades a mutable-tag hole for a staleness one. The two are one control.
# Note this was already true of cosign-installer, the one ref that WAS pinned: it
# sat on v3.9.2 with nothing watching it.
[ -f "$DEPENDABOT" ] || fail "no .github/dependabot.yml: the actions here are pinned to SHAs, so nothing ever bumps them"
grep -qE '^[[:space:]]*-[[:space:]]*package-ecosystem:[[:space:]]*"?github-actions"?' "$DEPENDABOT" \
  || fail "dependabot.yml has no \`github-actions\` entry, so the SHA-pinned actions are never bumped"

# --- 3. The group patterns must actually match every action in use.
#
# An ecosystem entry whose group patterns don't match an action leaves it outside
# the grouped PR, silently. This repo is exactly where that bites: `actions/*`
# would exclude sigstore/cosign-installer and aws-actions/configure-aws-credentials
# — the two refs in the jobs that hold signing and AWS authority.
#
# Rather than grep for a literal "*", extract the patterns and check coverage.
# Dependabot's only wildcard is `*`, which is also bash's, so `case` matches for
# free. sed picks up list items under a `patterns:` key only.
patterns=$(sed -nE '/^[[:space:]]*patterns:[[:space:]]*$/,/^[[:space:]]*[a-z-]+:[[:space:]]*$/ {
    s/^[[:space:]]*-[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/p
  }' "$DEPENDABOT" || true)
[ -n "$patterns" ] || fail "no group patterns found in $DEPENDABOT — without a group each action opens its own PR, and this check is asserting nothing"

uncovered=""
while IFS= read -r action; do
  [ -n "$action" ] || continue
  matched=0
  while IFS= read -r pat; do
    [ -n "$pat" ] || continue
    # shellcheck disable=SC2254  # the glob in $pat is the point
    case "$action" in $pat) matched=1; break ;; esac
  done <<<"$patterns"
  [ "$matched" = 1 ] || uncovered+="    $action"$'\n'
done <<<"$actions"

[ -z "$uncovered" ] || fail "these actions match no Dependabot group pattern, so they fall outside the grouped PR and stop being bumped:
$uncovered
Patterns present: $(tr '\n' ' ' <<<"$patterns")
Widen to \"*\"."

echo "CI hygiene OK: $(grep -c . <<<"$refs") action ref(s) pinned, Dependabot covers all $(grep -c . <<<"$actions") action(s)"
