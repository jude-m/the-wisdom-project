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
#
# Research backend: always the deployed Cloudflare Worker (even in debug), so
# "Research the Canon" works with no local server running. Without this the app
# defaults to http://localhost:8082 and shows "Couldn't connect".
# Endpoints — deployed: https://wisdom-research.bk-anigha.workers.dev
#             local:    http://localhost:8082 (scripts/research_server/run.sh)
# Point at a local server: RESEARCH_BASE_URL=http://localhost:8082 ./scripts/ios/run.sh

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
      echo "Usage: ./scripts/ios/run.sh [--debug | --release]"
      exit 1
      ;;
  esac
done

# Project root is two levels up: scripts/ios/ -> scripts/ -> project.
cd "$(dirname "$0")/../.."

echo "Running on iOS ($MODE)..."
echo "Research backend: $RESEARCH_BASE_URL"
flutter run -d ios "$MODE" \
  --dart-define=RESEARCH_BASE_URL="$RESEARCH_BASE_URL"
