#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
SOURCE="$ROOT/assets/icon.svg"
ICONSET="$ROOT/build/ClearNotifications.iconset"
OUTPUT="$ROOT/assets/ClearNotifications.icns"
MASTER="$ROOT/build/ClearNotifications-1024.png"

mkdir -p "$ROOT/build"
if [[ -e "$ICONSET" ]]; then
  PREVIOUS_ICONSET="$ROOT/build/ClearNotifications.previous.$(date +%Y%m%d%H%M%S).iconset"
  mv "$ICONSET" "$PREVIOUS_ICONSET"
fi
mkdir -p "$ICONSET"

/usr/bin/sips -s format png "$SOURCE" --out "$MASTER" >/dev/null

for size in 16 32 128 256 512; do
  /usr/bin/sips -z "$size" "$size" "$MASTER" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double_size=$((size * 2))
  /usr/bin/sips -z "$double_size" "$double_size" "$MASTER" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

/usr/bin/iconutil -c icns "$ICONSET" -o "$OUTPUT"
print -r -- "$OUTPUT"
