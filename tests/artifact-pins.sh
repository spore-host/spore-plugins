#!/usr/bin/env bash
# Asserts that plugins do not install what they have not verified.
#
# spawn verifies a `fetch` step's download against the sha256 the step pins, and
# refuses a `fetch` with no sha256 (spawn#838). This spec is what the release
# manifest's signature covers, so a pinned fetch is covered by the signature too.
# A download inside a `run` step's shell script is opaque to spawn: nothing
# checks it unless the script does. Two ways that has gone wrong, both checked:
#
#  1. A checksum check that cannot fail. mountpoint-s3 checked its .deb with
#     `sha256sum -c - || { echo note…; }` against the .rpm's checksum, so the
#     check always failed, `||` swallowed it, and apt-get installed a package
#     nothing had verified, as root (#31). Any `sha256sum -c` (or `shasum -c`)
#     whose failure is caught by `||` fails this test.
#
#  2. A new unpinned download. A remote `run` step that runs curl or wget
#     (against anything but localhost), or `pip install`, is an artifact spawn cannot verify. The
#     plugins that still do are listed in UNPINNED below, each one tracked in
#     #33; any OTHER plugin that does fails this test, and a listed plugin that
#     no longer does fails it too, so the list only shrinks. Move a download to
#     a `fetch` step with sha256 (and arch:, if it differs per architecture)
#     instead of adding to the list.
#
# Hermetic: reads plugins/*/plugin.yaml with yq (preinstalled on GitHub's Ubuntu
# runners). Local (controller-side) steps are not checked: they call APIs, they
# do not install artifacts on the instance.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Plugins whose remote steps still download unpinned artifacts (#33). Each is a
# known, accepted gap until it is fixed; do not add to this list.
UNPINNED=(
  cloudwatch-agent         # .rpm/.deb from .../latest/ when dnf has no package
  code-server              # curl https://code-server.dev/install.sh | sh
  docker                   # curl https://get.docker.com | sh off Amazon Linux
  github-actions-runner    # runner tarball, version from config, no checksum
  globus-personal-endpoint # globusconnectpersonal-latest.tgz
  jupyterlab               # pip install jupyterlab, unpinned
  rclone                   # curl https://rclone.org/install.sh | bash
  rstudio-server           # .rpm/.deb at whatever VERSION currently says
  tailscale                # curl https://tailscale.com/install.sh | sh
  vscode-tunnel            # .../latest/<arch>/stable tarball
)

command -v yq >/dev/null || { echo "artifact-pins: yq is required" >&2; exit 1; }

fail=0
err() { echo "ARTIFACT PINS FAILED: $*" >&2; fail=1; }

listed() {
  local n
  for n in "${UNPINNED[@]}"; do [ "$n" = "$1" ] && return 0; done
  return 1
}

# remote_scripts <plugin.yaml>: every remote run step's script, with
# backslash-continued lines joined so a URL on the next line still matches.
remote_scripts() {
  yq '.remote | .. | select(tag == "!!map" and .type == "run") | .run' "$1" \
    | sed -e ':a' -e '/\\$/N; s/\\\n//; ta'
}

shopt -s nullglob
specs=("$REPO"/plugins/*/plugin.yaml)
[ ${#specs[@]} -gt 0 ] || { echo "artifact-pins: no plugins found" >&2; exit 1; }

for spec in "${specs[@]}"; do
  name=$(basename "$(dirname "$spec")")
  scripts=$(remote_scripts "$spec")

  # 1. A checksum check whose failure is caught. Checked over the whole spec,
  # local steps included: a swallowed check is wrong wherever it is.
  if yq '.. | select(tag == "!!map" and .type == "run") | .run' "$spec" \
      | sed -e ':a' -e '/\\$/N; s/\\\n//; ta' \
      | grep -nE '(sha256sum|shasum)[^#]*-c[^#]*\|\|' >/dev/null; then
    err "$name: a sha256sum -c check is followed by || — a failed check must stop the step"
  fi

  # 2. Unpinned downloads in remote run steps.
  downloads=$(printf '%s\n' "$scripts" \
    | grep -E '(^|[^[:alnum:]_-])(curl|wget)[[:space:]]|pip3?[[:space:]]+install' \
    | grep -vE '(curl|wget)[^|;&]*[[:space:]](https?://)?(localhost|127\.0\.0\.1)([:/[:space:]]|$)' || true)
  if [ -n "$downloads" ] && ! listed "$name"; then
    err "$name: a remote run step downloads an artifact spawn cannot verify; use a fetch step with sha256:"
    printf '    %s\n' "$downloads" >&2
  fi
  if [ -z "$downloads" ] && listed "$name"; then
    err "$name: no longer downloads in a run step — remove it from UNPINNED in tests/artifact-pins.sh"
  fi

  # 3. Every fetch step pins its download (spawn refuses one that does not,
  # since spawn#838; this says so before a release does).
  unpinned=$(yq '.. | select(tag == "!!map" and .type == "fetch" and ((.sha256 // "") == "")) | .url' "$spec")
  if [ -n "$unpinned" ]; then
    err "$name: fetch step(s) without sha256: $unpinned"
  fi
done

for n in "${UNPINNED[@]}"; do
  [ -f "$REPO/plugins/$n/plugin.yaml" ] || err "UNPINNED lists $n, which is not a plugin"
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "artifact-pins: ${#specs[@]} plugins checked; ${#UNPINNED[@]} still download unpinned artifacts (#33)"
