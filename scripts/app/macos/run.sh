#!/bin/bash
# Build and run The Wisdom Project as a macOS desktop app.
#
# Usage:
#   ./scripts/app/macos/run.sh             # debug build (hot reload, slower)
#   ./scripts/app/macos/run.sh --debug     # same as above
#   ./scripts/app/macos/run.sh --profile   # profile build (release-speed + DevTools hooks)
#   ./scripts/app/macos/run.sh --release   # release build (faster, no hot reload)
#   -h, --help
#
# Debug is the default because it enables hot reload and assertions during
# development. Use --profile for performance investigation with DevTools
# (frame timings, CPU, memory) at near-release speed. Use --release to test
# against the production build.
#
# Research backend: this script ALWAYS points the app at the deployed
# Cloudflare Worker — even in debug — so "Research the Canon" works out of the
# box with no local server. (Without the --dart-define below the app defaults
# to http://localhost:8082, which is unreachable unless research_server is
# running locally, and shows a "Couldn't connect" error.)
#
# Endpoints (for reference):
#   deployed : RESEARCH_BASE_URL in scripts/config/targets.env
#   local    : http://localhost:8082   (via scripts/research_server/run.sh)
# Need the local server instead? Override without editing this file:
#   RESEARCH_BASE_URL=http://localhost:8082 ./scripts/app/macos/run.sh
# END-USAGE

set -e

. "$(dirname "$0")/../../lib/common.sh"

# --- Parse args -------------------------------------------------------------
MODE="--debug"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)   MODE="--debug";   shift ;;
    --profile) MODE="--profile"; shift ;;
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

echo "Running on macOS ($MODE)..."
echo "Research backend: $RESEARCH_BASE_URL"
flutter run -d macos "$MODE" \
  --dart-define=RESEARCH_BASE_URL="$RESEARCH_BASE_URL"
