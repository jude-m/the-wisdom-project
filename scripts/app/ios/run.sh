#!/bin/bash
# Build and run The Wisdom Project on the first available iOS device or
# simulator.
#
# Usage:
#   ./scripts/app/ios/run.sh             # debug build (hot reload, slower)
#   ./scripts/app/ios/run.sh --debug     # same as above
#   ./scripts/app/ios/run.sh --release   # release build (faster, no hot reload)
#   -h, --help
#
# Requires either an iOS Simulator to be booted (open Simulator.app) or a
# physical device connected and trusted. `flutter run -d ios` picks the
# first matching device.
#
# Research backend: always the deployed Cloudflare Worker (even in debug), so
# "Research the Canon" works with no local server running. Without this the app
# defaults to http://localhost:8082 and shows "Couldn't connect".
# Endpoints — deployed: RESEARCH_BASE_URL in scripts/config/targets.env
#             local:    http://localhost:8082 (scripts/research_server/run.sh)
# Point at a local server: RESEARCH_BASE_URL=http://localhost:8082 ./scripts/app/ios/run.sh
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

echo "Running on iOS ($MODE)..."
echo "Research backend: $RESEARCH_BASE_URL"
flutter run -d ios "$MODE" \
  --dart-define=RESEARCH_BASE_URL="$RESEARCH_BASE_URL"
