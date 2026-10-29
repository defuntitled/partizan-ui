#!/usr/bin/env bash
# Builds the core AAR in the partizan repo (scripts/build-android.sh there) and copies it to
# android/app/libs, where the app's Gradle build picks it up.
# PARTIZAN_CORE: path to the partizan repo (default: ../partizan next to this repo).
# With --no-build, only copies an AAR built before.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
core=${PARTIZAN_CORE:-$root/../partizan}

if [ "${1:-}" != "--no-build" ]; then
    "$core/scripts/build-android.sh"
fi
mkdir -p "$root/android/app/libs"
cp "$core/target/android/partizan-core.aar" "$root/android/app/libs/partizan-core.aar"
echo "copied $(wc -c < "$root/android/app/libs/partizan-core.aar") bytes to android/app/libs"
