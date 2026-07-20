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
#
# Research backend: always the deployed Cloudflare Worker (even in debug), so
# "Research the Canon" works with no local server running. Without this the app
# defaults to http://localhost:8082 and shows "Couldn't connect". (The deployed
# Worker is a public URL, so no 10.0.2.2 host-loopback trick is needed.)
# Endpoints — deployed: https://wisdom-research.bk-anigha.workers.dev
#             local:    http://localhost:8082 (scripts/research_server/run.sh)
# Point at a local server: RESEARCH_BASE_URL=http://10.0.2.2:8082 ./scripts/android/run.sh

set -e

# Deployed Worker by default; an exported RESEARCH_BASE_URL wins if set.
RESEARCH_BASE_URL="${RESEARCH_BASE_URL:-https://wisdom-research.bk-anigha.workers.dev}"

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
echo "Research backend: $RESEARCH_BASE_URL"
flutter run -d android "$MODE" \
  --dart-define=RESEARCH_BASE_URL="$RESEARCH_BASE_URL"
