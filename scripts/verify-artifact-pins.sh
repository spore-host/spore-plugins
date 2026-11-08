#!/usr/bin/env bash
# Verify every pinned plugin artifact at its origin.
#
# For each `fetch` step in plugins/*/plugin.yaml this downloads the URL and
# requires the bytes to have the step's sha256 and, when the step has one, its
# size. spored makes the same check on the instance; doing it here too means a
# mistyped pin fails the PR, not every install.
#
# Where the upstream signs its artifacts, the signature is checked as well, so a
# pin can only be one the upstream published:
#
#   https://s3.amazonaws.com/mountpoint-s3-release/...  Mountpoint for Amazon S3.
#     <url>.asc must verify against scripts/keys/mountpoint-s3.asc, made by one
#     of the two key fingerprints AWS lists in Mountpoint's INSTALL.md
#     ("Verifying the signature"); 673F…DA5A is the older key, which signed
#     1.19.0 and has since expired. An expired key still verifies a signature
#     made while it was valid; gpgv reports it as a good signature.
#
# A fetch URL with no known signature scheme is only hash- and size-checked, and
# is reported as such.
#
# Network: downloads every pinned artifact (about 51 MB today). No credentials.
# Needs curl, yq, gpg and gpgv.
#
# Usage: scripts/verify-artifact-pins.sh [plugins/<name>/plugin.yaml ...]
set -euo pipefail

cd "$(dirname "$0")/.."

# AWS's published Mountpoint release key fingerprints (awslabs/mountpoint-s3
# doc/INSTALL.md). The committed key file must contain exactly these.
MOUNTPOINT_FPRS=(
  8AEFE705EBE329C0948C75A66F1C3B3AEF4B030B
  673FE4061506BB469A0EF857BE397A52B086DA5A
)
MOUNTPOINT_KEY=scripts/keys/mountpoint-s3.asc

for tool in curl yq gpg gpgv; do
  command -v "$tool" >/dev/null || { echo "verify-artifact-pins: $tool is required" >&2; exit 1; }
done

work=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/artifact-pins.XXXXXX")
trap 'rm -rf "$work"' EXIT

# A keyring holding only the committed key, and a check that the key is the one
# AWS publishes: replacing the key file must not quietly change who we trust.
export GNUPGHOME="$work/gnupg"
mkdir -m 700 "$GNUPGHOME"
gpg --batch --quiet --dearmor <"$MOUNTPOINT_KEY" >"$work/mountpoint-s3.gpg"
key_fprs=$(gpg --batch --with-colons --show-keys "$MOUNTPOINT_KEY" 2>/dev/null \
  | awk -F: '$1 == "pub" { want = 1; next } want && $1 == "fpr" { print $10; want = 0 }' | sort)
want_fprs=$(printf '%s\n' "${MOUNTPOINT_FPRS[@]}" | sort)
if [ "$key_fprs" != "$want_fprs" ]; then
  echo "verify-artifact-pins: $MOUNTPOINT_KEY holds keys" >&2
  printf '  %s\n' $key_fprs >&2
  echo "but AWS publishes" >&2
  printf '  %s\n' $want_fprs >&2
  exit 1
fi

file_sha256() {
  if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}
file_size() { wc -c <"$1" | tr -d '[:space:]'; }

fail=0
checked=0
shopt -s nullglob
if [ $# -gt 0 ]; then specs=("$@"); else specs=(plugins/*/plugin.yaml); fi

for spec in "${specs[@]}"; do
  name=$(basename "$(dirname "$spec")")
  # url<TAB>sha256<TAB>size for every fetch step, in every section.
  while IFS=$'\t' read -r url sha size; do
    [ -n "$url" ] || continue
    checked=$((checked + 1))
    f="$work/artifact"
    rm -f "$f" "$f.asc"
    if ! curl -fsSL --retry 3 -o "$f" "$url"; then
      echo "  FAIL  $name  $url  — download failed" >&2
      fail=1
      continue
    fi
    got=$(file_sha256 "$f")
    if [ "$got" != "$sha" ]; then
      echo "  FAIL  $name  $url  — sha256 is $got, the spec pins $sha" >&2
      fail=1
      continue
    fi
    if [ -n "$size" ] && [ "$(file_size "$f")" != "$size" ]; then
      echo "  FAIL  $name  $url  — size is $(file_size "$f"), the spec pins $size" >&2
      fail=1
      continue
    fi

    case "$url" in
      https://s3.amazonaws.com/mountpoint-s3-release/*)
        if ! curl -fsSL --retry 3 -o "$f.asc" "$url.asc"; then
          echo "  FAIL  $name  $url  — no signature at $url.asc" >&2
          fail=1
          continue
        fi
        status=$(gpgv --keyring "$work/mountpoint-s3.gpg" --status-fd 1 "$f.asc" "$f" 2>/dev/null || true)
        signer=$(printf '%s\n' "$status" | awk '$2 == "VALIDSIG" { print $NF }')
        if [ -z "$signer" ] || ! printf '%s\n' "${MOUNTPOINT_FPRS[@]}" | grep -qFx "$signer"; then
          echo "  FAIL  $name  $url  — signature does not verify against AWS's Mountpoint key" >&2
          fail=1
          continue
        fi
        echo "  ok    $name  $url  (sha256, size, signed by $signer)"
        ;;
      *)
        echo "  ok    $name  $url  (sha256, size; upstream signature not checked)"
        ;;
    esac
  done < <(yq '.. | select(tag == "!!map" and .type == "fetch") | [.url, (.sha256 // ""), (.size // "")] | @tsv' "$spec")
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "verify-artifact-pins: $checked pinned artifact(s) verified"
