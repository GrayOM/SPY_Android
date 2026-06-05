# Device Monitor

A Flutter application for explicit, local-only device monitoring experiments.

## Current Scope

- User-controlled foreground monitoring.
- Local service event logs.
- Foreground location samples when permission is granted.
- Basic app and Android device diagnostics.

The project no longer includes remote data transmission, automatic background startup, SMS/contact/call-log collection, accessibility services, screen capture, or device-admin receivers.

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Use `./build_apk.sh` for a release APK build once Flutter and the Android SDK are installed.
