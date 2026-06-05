# Repository Guidelines

## Project Structure & Module Organization

This is a Flutter application named `spy_android`. Dart source lives in `lib/`, with UI screens in `lib/screens/` and background/data helpers in `lib/services/`. Tests live in `test/`, currently starting with `test/widget_test.dart`. Shared image and launcher assets are under `assets/images/` and `assets/icons/`, and are registered in `pubspec.yaml`. Platform projects are kept in `android/`, `ios/`, `web/`, `linux/`, `macos/`, and `windows/`; avoid editing generated platform files unless the change is platform-specific.

## Build, Test, and Development Commands

- `flutter pub get`: install Dart and Flutter dependencies from `pubspec.yaml`.
- `flutter analyze`: run static analysis using `analysis_options.yaml` and `flutter_lints`.
- `flutter test`: run widget and unit tests from `test/`.
- `flutter run`: launch the app on the selected device or emulator.
- `flutter build apk --debug`: build a debug Android APK for local validation.
- `flutter build apk --release`: build a release Android APK.
- `./build_apk.sh`: project helper for analysis, tests, and release APK collection.
- `./sign.sh`: helper for NOX/emulator-compatible APK builds.

## Coding Style & Naming Conventions

Use standard Dart formatting with two-space indentation. Run `dart format lib test` before submitting changes. Follow Flutter naming conventions: `PascalCase` for classes and widgets, `camelCase` for variables and methods, and `snake_case.dart` for file names. Keep screens in `lib/screens/`, services in `lib/services/`, and avoid mixing UI, persistence, and network logic in the same file.

## Testing Guidelines

Use `flutter_test` for widget and unit tests. Name test files with the `_test.dart` suffix and mirror the source area when practical, for example `test/services/tracking_service_test.dart`. Add tests for new service behavior, permission handling branches, and UI state changes. Always run `flutter analyze` and `flutter test` before opening a pull request.

## Commit & Pull Request Guidelines

Git history is not available in this checkout, so use concise imperative commit messages such as `Add settings validation` or `Fix APK build script`. Pull requests should include a short summary, test results, linked issues when applicable, and screenshots or screen recordings for UI changes. Note any Android permissions, background-service behavior, or configuration changes explicitly.

## Security & Configuration Tips

Do not commit real API keys, email service tokens, keystores, or device-specific secrets. Keep local signing and service credentials outside source control, and document required environment variables or manual setup in the PR description.
