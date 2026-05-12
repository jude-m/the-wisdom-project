#!/bin/bash
# Build and run The Wisdom Project on the first available Android device
# or emulator.
#
# Usage:
#   ./scripts/android/run.sh             # debug build (hot reload, slower)
#   ./scripts/android/run.sh --debug     # same as above
#   ./scripts/android/run.sh --release   # release build (faster, no hot reload)
#
# Requires either an Android emulator running (Android Studio → Device
# Manager) or a physical device with USB debugging enabled. `flutter run
# -d android` picks the first matching device.

set -e

# --- Parse args -------------------------------------------------------------
MODE="--debug"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)   MODE="--debug";   shift ;;
    --release) MODE="--release"; shift ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: ./scripts/android/run.sh [--debug | --release]"
      exit 1
      ;;
  esac
done

# Project root is two levels up: scripts/android/ -> scripts/ -> project.
cd "$(dirname "$0")/../.."

echo "Running on Android ($MODE)..."
flutter run -d android "$MODE"
