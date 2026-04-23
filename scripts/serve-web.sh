#!/bin/bash
# Build and serve The Wisdom Project for web testing.
#
# Usage:
#   ./scripts/serve-web.sh [--port 8080] [--skip-build]
#
# This script:
# 1. Builds the Flutter web app (unless --skip-build)
# 2. Starts the Dart server serving both API + web files
# 3. Opens http://localhost:PORT in your browser

set -e

PORT=8080
SKIP_BUILD=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)
      PORT="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: ./scripts/serve-web.sh [--port 8080] [--skip-build]"
      exit 1
      ;;
  esac
done

# Navigate to project root
cd "$(dirname "$0")/.."

# Step 1: Build Flutter web
if [ "$SKIP_BUILD" = false ]; then
  echo "Building Flutter web app..."
  flutter build web --release

  # Remove server-only assets from web build (databases + text JSON files).
  # On web these are served by the API — bundling them wastes ~600 MB.
  echo "Cleaning server-only assets from web build..."
  [ -d "build/web/assets/assets/databases" ] && rm -rf build/web/assets/assets/databases
  [ -d "build/web/assets/assets/text" ] && rm -rf build/web/assets/assets/text

  # Strip the Flutter service worker. Without it, redeploys show fresh
  # code immediately instead of serving a stale cached bundle until the
  # user hard-reloads. Losing offline support is fine — this app needs
  # the server running anyway.
  [ -f "build/web/flutter_service_worker.js" ] && rm -f build/web/flutter_service_worker.js

  SAVED=$(du -sh build/web | awk '{print $1}')
  echo "Web build size after cleanup: $SAVED"
  echo ""
fi

# Step 2: Install server dependencies (if needed)
if [ ! -d "server/.dart_tool" ]; then
  echo "Installing server dependencies..."
  cd server && dart pub get && cd ..
  echo ""
fi

# Step 3: Start server
echo "Starting server on port $PORT..."
echo "Open http://localhost:$PORT in your browser"
echo "Press Ctrl+C to stop"
echo ""

cd server
dart run bin/server.dart \
  --assets ../assets \
  --web-root ../build/web \
  --port "$PORT"
