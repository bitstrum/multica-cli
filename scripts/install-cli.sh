#!/usr/bin/env bash
# install-cli.sh <tag> — install that multica CLI release into ~/.local/bin (Linux amd64),
# verifying the tarball against the release's checksums.txt before it is ever executed.
set -euo pipefail
tag=${1:?tag}; asset="multica-cli-${tag#v}-linux-amd64.tar.gz"
base="https://github.com/multica-ai/multica/releases/download/${tag}"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/$asset" "$base/$asset"
curl -fsSL -o "$tmp/checksums.txt" "$base/checksums.txt"
# Anchor the filename and require exactly one entry, so a substring can never satisfy it.
[ "$(grep -c -E "[[:space:]]${asset}$" "$tmp/checksums.txt" || true)" = 1 ] || { echo "expected exactly 1 checksum entry for $asset" >&2; exit 1; }
(cd "$tmp" && grep -E "[[:space:]]${asset}$" checksums.txt | sha256sum --check --status) || { echo "checksum verification failed for $asset" >&2; exit 1; }
mkdir -p "$tmp/x" "$HOME/.local/bin"
tar -xzf "$tmp/$asset" -C "$tmp/x"
install -m 0755 "$tmp/x/multica" "$HOME/.local/bin/multica"
"$HOME/.local/bin/multica" version | head -1
