#!/bin/bash
set -euo pipefail

echo "Building Device Monitor debug APK for emulator testing..."

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed or is not in PATH."
  exit 1
fi

flutter pub get
flutter analyze
flutter build apk --debug --target-platform android-arm,android-x86 --no-shrink

output_dir="build/emulator_apks"
mkdir -p "$output_dir"

if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
  cp "build/app/outputs/flutter-apk/app-debug.apk" "$output_dir/DeviceMonitor_Debug.apk"
fi

echo "APK output: $output_dir"
