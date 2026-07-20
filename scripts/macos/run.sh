#!/bin/bash
# Build and run The Wisdom Project as a macOS desktop app.
#
# Usage:
#   ./scripts/macos/run.sh             # debug build (hot reload, slower)
#   ./scripts/macos/run.sh --debug     # same as above
#   ./scripts/macos/run.sh --profile   # profile build (release-speed + DevTools hooks)
#   ./scripts/macos/run.sh --release   # release build (faster, no hot reload)
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
#   deployed : https://wisdom-research.bk-anigha.workers.dev
#   local    : http://localhost:8082   (via scripts/research_server/run.sh)
# Need the local server instead? Override without editing this file:
#   RESEARCH_BASE_URL=http://localhost:8082 ./scripts/macos/run.sh

set -e

# Deployed Worker by default; an exported RESEARCH_BASE_URL wins if set.
RESEARCH_BASE_URL="${RESEARCH_BASE_URL:-https://wisdom-research.bk-anigha.workers.dev}"

# --- Parse args -------------------------------------------------------------
MODE="--debug"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)   MODE="--debug";   shift ;;
    --profile) MODE="--profile"; shift ;;
    --release) MODE="--release"; shift ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: ./scripts/macos/run.sh [--debug | --profile | --release]"
      exit 1
      ;;
  esac
done

# Project root is two levels up: scripts/macos/ -> scripts/ -> project.
cd "$(dirname "$0")/../.."

echo "Running on macOS ($MODE)..."
echo "Research backend: $RESEARCH_BASE_URL"
flutter run -d macos "$MODE" \
  --dart-define=RESEARCH_BASE_URL="$RESEARCH_BASE_URL"
