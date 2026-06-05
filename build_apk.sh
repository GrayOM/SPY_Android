#!/bin/bash
set -euo pipefail

echo "Building Device Monitor APK..."

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed or is not in PATH."
  exit 1
fi

flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-debug-info=build/app/outputs/symbols

output_dir="build/device_monitor_apks"
mkdir -p "$output_dir"

if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
  cp "build/app/outputs/flutter-apk/app-release.apk" "$output_dir/DeviceMonitor_Universal_v1.0.apk"
fi

for abi in arm64-v8a armeabi-v7a; do
  apk="build/app/outputs/flutter-apk/app-$abi-release.apk"
  if [ -f "$apk" ]; then
    cp "$apk" "$output_dir/DeviceMonitor_${abi}_v1.0.apk"
  fi
done

echo "APK output: $output_dir"
