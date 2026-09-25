#!/bin/bash
# Build and run The Wisdom Project on the first available Android device
# or emulator.
#
# Usage:
#   ./scripts/app/android/run.sh             # debug build (hot reload, slower)
#   ./scripts/app/android/run.sh --debug     # same as above
#   ./scripts/app/android/run.sh --release   # release build (faster, no hot reload)
#   -h, --help
#
# Requires either an Android emulator running (Android Studio → Device
# Manager) or a physical device with USB debugging enabled. `flutter run
# -d android` picks the first matching device.
#
# Research backend: always the deployed Cloudflare Worker (even in debug), so
# "Research the Canon" works with no local server running. Without this the app
# defaults to http://localhost:8082 and shows "Couldn't connect". (The deployed
# Worker is a public URL, so no 10.0.2.2 host-loopback trick is needed.)
# Endpoints — deployed: RESEARCH_BASE_URL in scripts/config/targets.env
#             local:    http://localhost:8082 (scripts/research_server/run.sh)
# Point at a local server: RESEARCH_BASE_URL=http://10.0.2.2:8082 ./scripts/app/android/run.sh
# END-USAGE

set -e

. "$(dirname "$0")/../../lib/common.sh"

# --- Parse args -------------------------------------------------------------
MODE="--debug"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)   MODE="--debug";   shift ;;
    --release) MODE="--release"; shift ;;
    -h|--help) usage ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Run with -h for help." >&2
      exit 1
      ;;
  esac
done

# Deployed Worker by default; an exported RESEARCH_BASE_URL wins if set.
RESEARCH_BASE_URL="${RESEARCH_BASE_URL:-$(target RESEARCH_BASE_URL)}"

cd "$WISDOM_ROOT"

echo "Running on Android ($MODE)..."
echo "Research backend: $RESEARCH_BASE_URL"
flutter run -d android "$MODE" \
  --dart-define=RESEARCH_BASE_URL="$RESEARCH_BASE_URL"
