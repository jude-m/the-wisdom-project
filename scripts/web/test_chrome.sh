#!/bin/bash
# Run the integration test suite against the web build in Chrome, on macOS.
#
# Usage:
#   ./scripts/web/test_chrome.sh                       # every file, release, headless
#   ./scripts/web/test_chrome.sh in_page_search_test   # one file (name or path)
#   ./scripts/web/test_chrome.sh --show                # watch it in a visible window
#   ./scripts/web/test_chrome.sh --debug               # debug build (slower, heavier)
#   ./scripts/web/test_chrome.sh [--port 8091] [--driver-port 4444]
#                                [--first-visit] [-h]
#
# macOS runs the same suite with `flutter test integration_test/all_tests.dart
# -d macos` — one app launch for every file. The web cannot do that: `flutter
# test` refuses an integration test on a browser device, so the only supported
# path is `flutter drive` through chromedriver, and eleven files in one browser
# session exhausts it (the tab dies with "invalid session id"). So this script
# starts one `flutter drive` per file instead.
#
# The file list is not written here: it is read from the imports of
# integration_test/all_tests.dart, the same list macOS runs. Add a file there
# and both platforms pick it up.
#
# The cross-origin isolation headers the database needs come from
# `web_dev_config.yaml` at the repo root; `flutter drive` reads it by itself,
# the same as `flutter run`.
#
# --first-visit deletes the Chrome profile, so the run re-downloads the ~335 MB
# of databases into a fresh private file system — that is the code path a real
# first visitor takes. Without it the profile is kept and the databases install
# only once, which is why a normal run starts in seconds.
#
# --show drops --headless so the browser is visible. Useful when a test fails
# for a reason the log does not explain.
#
# chromedriver is downloaded on demand into .dart_tool/, matched to the major
# version of the installed Chrome. Chrome updates itself, so a mismatch is the
# one thing that reliably breaks this; deleting .dart_tool/chromedriver-* forces
# a fresh one.
# END-USAGE

set -e

BUILD_MODE="release"
HEADLESS="--headless"
PORT=8091
DRIVER_PORT=4444
FIRST_VISIT=false
ONLY=""

usage() {
  sed -n '2,/^# END-USAGE$/p' "$0" | sed 's/^# \{0,1\}//; /^END-USAGE$/d'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) PORT="$2"; shift 2 ;;
    --driver-port) DRIVER_PORT="$2"; shift 2 ;;
    --debug|--profile|--release) BUILD_MODE="${1#--}"; shift ;;
    --show) HEADLESS=""; shift ;;
    --first-visit) FIRST_VISIT=true; shift ;;
    -h|--help) usage ;;
    -*) echo "Unknown option: $1"; echo "Run with --help for usage."; exit 1 ;;
    *) ONLY="$1"; shift ;;
  esac
done

# Project root is two levels up: scripts/web/ -> scripts/ -> project.
cd "$(dirname "$0")/../.."

if [ ! -f test_driver/integration_test.dart ]; then
  echo "test_driver/integration_test.dart is missing — flutter drive needs it."
  exit 1
fi

# --- which files ----------------------------------------------------------
# One source of truth: whatever all_tests.dart imports.
if [ -n "$ONLY" ]; then
  FILES="$(basename "${ONLY%.dart}").dart"
  if [ ! -f "integration_test/$FILES" ]; then
    echo "integration_test/$FILES does not exist."
    exit 1
  fi
else
  FILES=$(sed -n "s/^import '\(.*_test\.dart\)'.*/\1/p" integration_test/all_tests.dart)
  # Running nothing must not report green.
  if [ -z "$FILES" ]; then
    echo "No test files: integration_test/all_tests.dart imports none."
    exit 1
  fi
fi

PROFILE="$PWD/.dart_tool/web-test-chrome"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$CHROME" ] || { echo "Google Chrome not found at $CHROME"; exit 1; }

# --- chromedriver, matched to the installed Chrome -------------------------
MAJOR=$("$CHROME" --version | sed -E 's/[^0-9]*([0-9]+).*/\1/')
DRIVER_DIR=".dart_tool/chromedriver-$MAJOR"
DRIVER="$DRIVER_DIR/chromedriver-mac-arm64/chromedriver"
if [ ! -x "$DRIVER" ]; then
  echo "Fetching chromedriver for Chrome $MAJOR..."
  VERSION=$(curl -sSf "https://googlechromelabs.github.io/chrome-for-testing/LATEST_RELEASE_$MAJOR")
  mkdir -p "$DRIVER_DIR"
  curl -sSfL -o "$DRIVER_DIR/chromedriver.zip" \
    "https://storage.googleapis.com/chrome-for-testing-public/$VERSION/mac-arm64/chromedriver-mac-arm64.zip"
  unzip -qo "$DRIVER_DIR/chromedriver.zip" -d "$DRIVER_DIR"
  xattr -d com.apple.quarantine "$DRIVER" 2>/dev/null || true
fi

if lsof -ti "tcp:$PORT" >/dev/null 2>&1; then
  echo "Port $PORT is in use — stop what is on it or pass --port."
  exit 1
fi

# chromedriver is started with `&`, so a failed bind would not stop the script:
# the run would quietly drive whatever is already on the port, possibly a driver
# built for another Chrome — the one mismatch this script exists to prevent.
if lsof -ti "tcp:$DRIVER_PORT" >/dev/null 2>&1; then
  echo "Port $DRIVER_PORT is in use — stop that chromedriver or pass --driver-port."
  exit 1
fi

if [ "$FIRST_VISIT" = true ]; then
  echo "Deleting the test Chrome profile: the databases will download again."
  rm -rf "$PROFILE"
fi

# --enable-chrome-logs puts the browser console into the chromedriver log. Not
# optional: on web `flutter drive` reports a failure as a bare "Failure in
# method: <name>" with no message, so without this a failing test says nothing
# about why it failed.
LOG=".dart_tool/chromedriver.log"
"$DRIVER" --port="$DRIVER_PORT" --enable-chrome-logs > "$LOG" 2>&1 &
DRIVER_PID=$!
trap 'kill $DRIVER_PID 2>/dev/null' EXIT
READY=false
for _ in $(seq 1 60); do
  if curl -sf "http://localhost:$DRIVER_PORT/status" >/dev/null 2>&1; then
    READY=true
    break
  fi
  sleep 0.5
done
if [ "$READY" = false ]; then
  echo "chromedriver never answered on port $DRIVER_PORT. Last lines of $LOG:"
  tail -5 "$LOG"
  exit 1
fi

FAILED=""
for f in $FILES; do
  echo ""
  echo "── $f ───────────────────────────────────────────"
  # `|| FAILED=...` instead of set -e, so one red file still runs the rest.
  flutter drive \
    --driver=test_driver/integration_test.dart \
    --target="integration_test/$f" \
    -d web-server \
    --"$BUILD_MODE" \
    --web-hostname=localhost \
    --web-port="$PORT" \
    --browser-name=chrome \
    --driver-port="$DRIVER_PORT" \
    $HEADLESS \
    --web-browser-flag=--user-data-dir="$PROFILE" \
    || FAILED="$FAILED $f"
done

echo ""
if [ -n "$FAILED" ]; then
  echo "FAILED:$FAILED"
  echo "Browser console for the run is in $LOG"
  exit 1
fi
echo "All files passed in Chrome."
