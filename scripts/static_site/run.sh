#!/bin/bash
# Build the static HTML site and preview it locally — one command, done.
#
# Usage:
#   ./scripts/static_site/run.sh                        # whole corpus, ~25s, then serve
#   ./scripts/static_site/run.sh --root an-1,atta-an-1  # one subtree + its commentary (fast)
#   ./scripts/static_site/run.sh --skip-build           # serve build/ as it stands
#   ./scripts/static_site/run.sh --port 9000            # override the port (default 8083)
#   -h, --help
#
# Dev port map: 8080/8081 Flutter web, 8082 research server, 8083 this.
# 8787 is skipped — it is wrangler's own default.
#
# --port reaches the generator too: every page carries a `rel="canonical"`
# naming a full origin, so the build and the server that opens it must agree.
#
# tool/serve.dart, not `python3 -m http.server` — every generated link is
# extensionless (`/tipitaka/an-1-2` against `an-1-2.html`), the way Cloudflare
# Pages serves it. A naive server renders the pages and 404s every link.
#
# --root is preview-only: a subtree links outside itself, so those links 404.
# For a check against real Cloudflare behaviour, deploy a preview instead:
# ./scripts/static_site/deploy.sh
# END-USAGE

set -e

# --- Parse args -------------------------------------------------------------
PORT=8083
ROOTS="all"
ROOTS_SET=false
SKIP_BUILD=0

usage() {
  sed -n '2,/^# END-USAGE$/p' "$0" | sed 's/^# \{0,1\}//; /^END-USAGE$/d'
  exit 0
}

while [[ $# -gt 0 ]]; do
  # Values are checked before `shift 2`, which fails under `set -e` and kills
  # the script with no message at all. (deploy.sh documents the same trap.)
  case "$1" in
    --port)
      # Before the build as well as before the shift: the port is baked into
      # every canonical, so a bad one wastes the build. 1-5 digits.
      case "${2:-}" in
        ''|*[!0-9]*|0*|??????*)
          echo "error: --port needs a number, e.g. --port 8083." >&2
          exit 1 ;;
      esac
      PORT="$2"; shift 2 ;;
    --root)
      if [ -z "${2:-}" ]; then
        echo "error: --root needs a value, e.g. --root an-1,atta-an-1 (or 'all')." >&2
        exit 1
      fi
      ROOTS="$2"; ROOTS_SET=true; shift 2 ;;
    --skip-build) SKIP_BUILD=1; shift ;;
    -h|--help)    usage ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Run with -h for help." >&2
      exit 1
      ;;
  esac
done

# Project root is two levels up: scripts/static_site/ -> scripts/ -> project.
cd "$(dirname "$0")/../.."

ORIGIN="http://localhost:$PORT"

# --- Build ------------------------------------------------------------------
if [ "$SKIP_BUILD" -eq 1 ]; then
  # --root only reaches the generator, so pairing the two asks for something
  # this script cannot do. (Same guard as deploy.sh.)
  if [ "$ROOTS_SET" = true ]; then
    echo "warning: --root is ignored with --skip-build; serving build/ as it stands." >&2
  fi
  echo "Skipping build — serving static_site_generator/build as it stands."
else
  echo "Building static site (--root $ROOTS, origin $ORIGIN)..."
  dart run static_site_generator/bin/generate.dart --root "$ROOTS" --origin "$ORIGIN"
  echo ""
fi

# --- Free the port ----------------------------------------------------------
# A re-run otherwise hits "address already in use". Kill, then wait until the
# port is genuinely released — a fixed sleep is racy. -sTCP:LISTEN so a browser
# tab holding a keep-alive to the preview is not itself a kill target.
PIDS=$(lsof -ti:"$PORT" -sTCP:LISTEN 2>/dev/null || true)
if [ -n "$PIDS" ]; then
  echo "Stopping process on port $PORT (PID: $PIDS)..."
  echo "$PIDS" | xargs kill 2>/dev/null || true
  for _ in $(seq 1 10); do
    sleep 0.5
    PIDS=$(lsof -ti:"$PORT" -sTCP:LISTEN 2>/dev/null || true)
    [ -z "$PIDS" ] && break
    echo "$PIDS" | xargs kill -9 2>/dev/null || true
  done
fi

# --- Serve ------------------------------------------------------------------
# exec so Ctrl+C reaches serve.dart directly.
exec dart run static_site_generator/tool/serve.dart --port "$PORT"
