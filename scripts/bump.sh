#!/bin/sh
# Regenerates bucket/mstream-player.json from a release's manifest.json.
#
#   scripts/bump.sh v0.1.0
#
# Same arrangement as the Homebrew tap's bump.sh: the manifest is
# generated, never hand-edited, and the player repo's release workflow
# runs this after each tag. The hash comes from the manifest the release
# publishes beside its binaries. checkver/autoupdate stay in the output
# so scoop's own tooling agrees about versions, but the push from the
# release is what actually updates this bucket.
set -eu

tag="${1:?usage: bump.sh vX.Y.Z}"
version="${tag#v}"
repo="IrosTheBeggar/mstream-terminal-player"
base="https://github.com/${repo}/releases/download/${tag}"

manifest=$(mktemp)
trap 'rm -f "${manifest}"' EXIT INT TERM
if command -v curl >/dev/null 2>&1
then
  curl -fsSL -o "${manifest}" "${base}/manifest.json"
else
  wget -qO "${manifest}" "${base}/manifest.json"
fi

hash=$(
  set -e
  sed -n 's/.*"file": "mstream-player-win32-x64\.exe", "sha256": "\([0-9a-f]\{64\}\)".*/\1/p' "${manifest}"
)
case "${hash}" in
  "" | *[!0-9a-f]*)
    echo "manifest.json is missing the windows hash — refusing to write" >&2
    exit 1
    ;;
  *) ;;
esac

scriptdir=$(dirname "${0}")
cat >"${scriptdir}/../bucket/mstream-player.json" <<JSON
{
    "version": "${version}",
    "description": "Terminal player and headless server-audio engine for mStream",
    "homepage": "https://github.com/IrosTheBeggar/mstream-terminal-player",
    "license": "GPL-3.0-only",
    "url": "${base}/mstream-player-win32-x64.exe#/mstream-player.exe",
    "hash": "${hash}",
    "bin": "mstream-player.exe",
    "checkver": {
        "github": "https://github.com/IrosTheBeggar/mstream-terminal-player"
    },
    "autoupdate": {
        "url": "https://github.com/IrosTheBeggar/mstream-terminal-player/releases/download/v\$version/mstream-player-win32-x64.exe#/mstream-player.exe",
        "hash": {
            "url": "https://github.com/IrosTheBeggar/mstream-terminal-player/releases/download/v\$version/manifest.json",
            "jsonpath": "$.assets[?(@.file == 'mstream-player-win32-x64.exe')].sha256"
        }
    }
}
JSON
echo "bucket/mstream-player.json -> ${version}"
