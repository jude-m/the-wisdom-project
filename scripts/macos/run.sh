#!/bin/bash
# Build and run The Wisdom Project as a macOS desktop app.
#
# Usage:
#   ./scripts/macos/run.sh             # debug build (hot reload, slower)
#   ./scripts/macos/run.sh --debug     # same as above
#   ./scripts/macos/run.sh --release   # release build (faster, no hot reload)
#
# Debug is the default because it enables hot reload and assertions during
# development. Use --release to test performance against the production build.

set -e

# --- Parse args -------------------------------------------------------------
MODE="--debug"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)   MODE="--debug";   shift ;;
    --release) MODE="--release"; shift ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: ./scripts/macos/run.sh [--debug | --release]"
      exit 1
      ;;
  esac
done

# Project root is two levels up: scripts/macos/ -> scripts/ -> project.
cd "$(dirname "$0")/../.."

echo "Running on macOS ($MODE)..."
flutter run -d macos "$MODE"
