#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
VERSION="${1:-0.1.0}"
DIST="$ROOT/dist"

cd "$ROOT"
"$ROOT/Scripts/check-release.sh"

mkdir -p "$DIST"
git archive \
  --format=tar.gz \
  --prefix="clear-notifications-macos-v${VERSION}/" \
  --output="$DIST/clear-notifications-macos-v${VERSION}-source.tar.gz" \
  HEAD

shasum -a 256 "$DIST/clear-notifications-macos-v${VERSION}-source.tar.gz" \
  > "$DIST/SHA256SUMS.txt"

print -r -- "$DIST"
