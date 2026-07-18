# Clear Notifications for macOS

Clear visible Notification Center alerts in one click.

No account. No tracking. No background service. The app runs locally, dismisses the currently visible notifications, and exits.

> **Public beta:** The source is ready for review and local builds. A prebuilt download will be added only after Apple Developer ID signing and notarization are available.

## What it does

- Dismisses visible macOS Notification Center cards and stacks.
- Opens Notification Center when needed, then closes it when finished.
- Requests Accessibility permission once through the normal macOS prompt.
- Supports `--dry-run --no-open` for non-destructive verification.

It does **not** read notification text, send data, disable future notifications, alter Login Items, or run continuously.

## Requirements

- macOS 13 or later.
- Swift 6 / Apple Command Line Tools.
- Accessibility permission for the built app.

## Build and test

```sh
git clone https://github.com/diglabai/clear-notifications-macos.git
cd clear-notifications-macos
./Scripts/build-app.sh
```

The app is created at `build/Clear Notifications.app`.

Install it locally:

```sh
mkdir -p "$HOME/Applications"
cp -R "build/Clear Notifications.app" "$HOME/Applications/"
```

Drag the app to the Dock, click it, and grant Accessibility permission when macOS asks.

## Privacy-safe dry run

```sh
"build/Clear Notifications.app/Contents/MacOS/ClearNotifications" --dry-run --no-open
```

The command reports only whether Accessibility permission is available and how many dismissible controls are exposed. It never prints notification content.

## Why source-only first?

macOS Gatekeeper expects public downloads to use Apple Developer ID signing, hardened runtime, a secure timestamp, and notarization. This repository does not publish a self-signed or machine-local binary as a trusted public download.

## Known limitations

- Apple provides no public API for adding a custom button inside Notification Center, so this is a Dock app.
- Notification Center is controlled through macOS Accessibility and may require maintenance after major macOS UI changes.
- The current compatibility proof covers macOS 15.7.7; more clean-machine versions are planned.

## Security and privacy

See [PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md).

## License

MIT © 2026 [diglabai](https://github.com/diglabai)
