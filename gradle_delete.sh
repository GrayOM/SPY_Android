#!/bin/bash
set -euo pipefail

rm -rf android/.gradle android/build android/app/build build
flutter clean
flutter pub get
flutter build apk --debug
