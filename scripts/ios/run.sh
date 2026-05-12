#!/bin/bash
# Build and run The Wisdom Project on the first available iOS device or
# simulator.
#
# Usage:
#   ./scripts/ios/run.sh             # debug build (hot reload, slower)
#   ./scripts/ios/run.sh --debug     # same as above
#   ./scripts/ios/run.sh --release   # release build (faster, no hot reload)
#
# Requires either an iOS Simulator to be booted (open Simulator.app) or a
# physical device connected and trusted. `flutter run -d ios` picks the
# first matching device.

set -e

# --- Parse args -------------------------------------------------------------
MODE="--debug"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)   MODE="--debug";   shift ;;
    --release) MODE="--release"; shift ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: ./scripts/ios/run.sh [--debug | --release]"
      exit 1
      ;;
  esac
done

# Project root is two levels up: scripts/ios/ -> scripts/ -> project.
cd "$(dirname "$0")/../.."

echo "Running on iOS ($MODE)..."
flutter run -d ios "$MODE"
