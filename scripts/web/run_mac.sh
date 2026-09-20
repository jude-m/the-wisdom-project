#!/bin/bash
# Build and serve The Wisdom Project for web testing on macOS.
#
# Usage:
#   ./scripts/web/run_mac.sh             # debug build (default)
#   ./scripts/web/run_mac.sh --debug     # same as above
#   ./scripts/web/run_mac.sh --profile   # profile build (perf measurement)
#   ./scripts/web/run_mac.sh --release   # release build (production-equivalent)
#   ./scripts/web/run_mac.sh [--port 8080] [--clean]
#
# Flutter's own dev server builds and serves in one command; there is no Dart
# server any more. The app downloads bjt.db and dict.db into the browser's
# private file system on the first visit, so the first run of a new database
# takes a while and later runs start at once.
#
# Open the printed URL in your usual Chrome — not `flutter run -d chrome`,
# which starts a throwaway profile and copies the downloaded databases in and
# out of `.dart_tool/chrome-device` on every run.
#
# The cross-origin isolation headers the database storage needs come from
# `web_dev_config.yaml` at the repo root; `flutter run` reads it by itself.
#
# Debug is the default (kDebugMode true, debugPrint visible in the browser
# DevTools console at F12 → Console), matching the native run scripts.
#
# --profile builds with --profile. Use this for performance measurement:
# realistic frame timings (debug is far slower and not representative) while
# still allowing Chrome DevTools profiling. Pair it with Chrome DevTools →
# Performance → CPU 6× throttle to emulate an older machine.
#
# --release is the production-equivalent bundle (smaller, fastest) when you
# need to sanity-check the real deployed build locally.
#
# --clean runs `flutter clean` + `flutter pub get` first. Use this when cached
# build artifacts are stale — e.g. after changing fonts in pubspec.yaml, since
# the web FontManifest.json is cached aggressively.
# END-USAGE

set -e

PORT=8080
BUILD_MODE="debug"
CLEAN=false

# Research backend baked into the web build (a compile-time constant read via
# String.fromEnvironment). Always the deployed Cloudflare Worker by default; an
# exported RESEARCH_BASE_URL wins.
#
# CORS CAVEAT (web only): the browser enforces the Worker's CORS allow-list
# (RESEARCH_CORS_ORIGINS in research_server/wrangler.jsonc). It lists
# http://localhost:8080, the default here; with another --port, research calls
# are CORS-blocked until that origin is added and the Worker redeployed. Native
# platforms don't hit this — only the browser does.
RESEARCH_BASE_URL="${RESEARCH_BASE_URL:-https://wisdom-research.bk-anigha.workers.dev}"

# The header above is the --help text, to the sentinel; the idiom the static-site
# scripts use (docs/decisions/static-web-hosting.md), so an edit can't desync it.
usage() {
  sed -n '2,/^# END-USAGE$/p' "$0" | sed 's/^# \{0,1\}//; /^END-USAGE$/d'
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)
      PORT="$2"
      shift 2
      ;;
    --debug|--profile|--release)
      BUILD_MODE="${1#--}"
      shift
      ;;
    --clean)
      CLEAN=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run with --help for usage."
      exit 1
      ;;
  esac
done

# Project root is two levels up: scripts/web/ -> scripts/ -> project.
cd "$(dirname "$0")/../.."

if [ "$CLEAN" = true ]; then
  echo "Cleaning build artifacts..."
  flutter clean
  flutter pub get
  echo ""
fi

echo "Serving The Wisdom Project for web ($BUILD_MODE)..."
echo "Open http://localhost:$PORT in your browser"
echo "Press q in this terminal to stop"
echo ""

# --web-hostname localhost, because cross-origin isolation needs a secure
# context and http://localhost is one; the default host is 0.0.0.0, which is
# not. --no-web-resources-cdn keeps CanvasKit local: Google's CDN copy has not
# been tried under `Cross-Origin-Embedder-Policy: require-corp`.
exec flutter run -d web-server \
  --"$BUILD_MODE" \
  --no-web-resources-cdn \
  --web-hostname localhost \
  --web-port "$PORT" \
  --dart-define=RESEARCH_BASE_URL="$RESEARCH_BASE_URL"
