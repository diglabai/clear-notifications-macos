#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP_NAME="Clear Notifications.app"
BUILD_ROOT="$ROOT/build"
APP="$BUILD_ROOT/$APP_NAME"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"

swift test --package-path "$ROOT"
swift build --package-path "$ROOT" -c release
"$ROOT/Scripts/generate-icon.sh"

BIN_PATH="$(swift build --package-path "$ROOT" -c release --show-bin-path)/ClearNotifications"
[[ -x "$BIN_PATH" ]]

if [[ -e "$APP" ]]; then
  PREVIOUS_APP="$BUILD_ROOT/Clear Notifications.previous.$(date +%Y%m%d%H%M%S).app"
  mv "$APP" "$PREVIOUS_APP"
fi
mkdir -p "$MACOS" "$RESOURCES"
cp "$BIN_PATH" "$MACOS/ClearNotifications"
cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/assets/ClearNotifications.icns" "$RESOURCES/ClearNotifications.icns"

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  codesign --force --deep --sign - --timestamp=none "$APP"
else
  codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
fi

codesign --verify --deep --strict --verbose=2 "$APP"
plutil -lint "$CONTENTS/Info.plist"

print -r -- "$APP"
