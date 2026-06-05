# Android_helper

A Flutter application for consent-based dementia care guardian location sharing.

## Current Scope

- User-controlled guardian location sharing.
- Periodic location samples while sharing is enabled.
- Local guardian web administration page for the latest location and encrypted safe-storage metadata.
- Configurable backend endpoints for sending physical location updates.
- Emergency profile card information for urgent dementia care support.
- Encrypted safe storage backed by Android Keystore.

The app does not request camera, microphone, SMS, call-log, contact, accessibility, device-admin, screen-capture, installed-app-list, or overlay-capture capabilities.

## Android Compatibility

- `minSdk` remains `24`.
- `compileSdk` and `targetSdk` remain `35` in this checkout because SDK 36 is not configured here.
- The app is intended to install on current Samsung Android 16 / One UI 8.5 devices while retaining lower Flutter-enabled Android compatibility.

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Use `./build_apk.sh` for a release APK build once Flutter and the Android SDK are installed.
