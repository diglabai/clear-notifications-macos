#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
DIST="$ROOT/dist"

cd "$ROOT"

ensure_clean_source() {
  if ! git diff --quiet || ! git diff --cached --quiet; then
    print -u2 -- "Source archive requires a clean tracked working tree and index. Commit or stash tracked changes first."
    exit 1
  fi
}

ensure_clean_source
SOURCE_COMMIT="$(git rev-parse --verify HEAD)"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Info.plist")}"

"$ROOT/Scripts/check-release.sh"
ensure_clean_source
if [[ "$(git rev-parse --verify HEAD)" != "$SOURCE_COMMIT" ]]; then
  print -u2 -- "Source revision changed during verification. Run the archive command again."
  exit 1
fi

mkdir -p "$DIST"
git archive \
  --format=tar.gz \
  --prefix="clear-notifications-macos-v${VERSION}/" \
  --output="$DIST/clear-notifications-macos-v${VERSION}-source.tar.gz" \
  "$SOURCE_COMMIT"

(
  cd "$DIST"
  shasum -a 256 "clear-notifications-macos-v${VERSION}-source.tar.gz" > SHA256SUMS.txt
)

print -r -- "$DIST"
