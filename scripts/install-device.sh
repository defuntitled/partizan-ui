#!/usr/bin/env bash
# Builds the app and installs it on a device: scripts/install-device.sh [adb serial].
# Always rebuilds: `flutter test integration_test` leaves its own APK at the same path, and that
# one waits on the splash screen for a test runner that never comes.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
serial=(${1:+-s "$1"})
flutter build apk --debug --target-platform android-arm64
adb "${serial[@]}" install -r build/app/outputs/flutter-apk/app-debug.apk
adb "${serial[@]}" shell monkey -p partizan.client -c android.intent.category.LAUNCHER 1 >/dev/null
