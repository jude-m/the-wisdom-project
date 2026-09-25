#!/bin/bash
# Run the research_server (the /research AI Q&A backend) locally — one command, done.
#
# Usage:
#   ./scripts/research_server/run.sh              # wrangler dev (Workers runtime), auto-reload
#   ./scripts/research_server/run.sh --node       # plain Node entry — shows cpu=/build= debug timers
#   ./scripts/research_server/run.sh --port 8083  # override the port (default 8082)
#   -h, --help
#
# Dev port map: 8080 = Flutter web (macOS), 8081 = Flutter web (Windows box),
# 8082 = research server, 8083 = static-site preview
# (static_site_generator/tool/serve.dart). The Dart content server that used to
# hold 8081 is retired.
#
# The Gemini key comes from scripts/config/secrets.env (RESEARCH_GEMINI_API_KEY;
# copy secrets.env.example). wrangler gets it through a temporary --env-file,
# which also stops it reading any old research_server/.dev.vars. RESEARCH_STUB
# and RESEARCH_STORE come from wrangler.jsonc: wrangler reads them there itself,
# and --node passes them on, since plain Node never reads that file. It stops
# first if the key can't open RESEARCH_STORE: both belong to one Google project.
# END-USAGE

set -e

. "$(dirname "$0")/../lib/common.sh"

# --- Parse args -------------------------------------------------------------
PORT=8082
RUNTIME="wrangler"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)
      # Checked before `shift 2`, which fails under `set -e` with no message.
      case "${2:-}" in
        ''|*[!0-9]*|0*|??????*)
          echo "error: --port needs a number, e.g. --port 8082." >&2
          exit 1 ;;
      esac
      PORT="$2"; shift 2 ;;
    --node)    RUNTIME="node"; shift ;;
    -h|--help) usage ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Run with -h for help." >&2
      exit 1
      ;;
  esac
done

cd "$WISDOM_ROOT/research_server"

require_node22

if [ -z "$(secret RESEARCH_GEMINI_API_KEY)" ]; then
  echo "error: RESEARCH_GEMINI_API_KEY is not set (environment or" >&2
  echo "       scripts/config/secrets.env) — research needs a Gemini key." >&2
  exit 1
fi

research_deps
check_research_store
free_port "$PORT"

echo "Starting research_server on http://localhost:$PORT ($RUNTIME)"
echo "Health check: curl localhost:$PORT/health"
echo "Press Ctrl+C to stop"
echo ""

if [ "$RUNTIME" = "node" ]; then
  npm run build
  STUB=$(research_var RESEARCH_STUB)
  STORE=$(research_var RESEARCH_STORE)
  PORT="$PORT" RESEARCH_STUB="$STUB" RESEARCH_STORE="$STORE" \
    GEMINI_API_KEY="$(secret RESEARCH_GEMINI_API_KEY)" \
    exec node dist/src/node.js
else
  ENV_TMP=$(mktemp "${TMPDIR:-/tmp}/wisdom-research-env.XXXXXX")
  trap 'rm -f "$ENV_TMP"' EXIT
  write_worker_secrets "$ENV_TMP" GEMINI_API_KEY=RESEARCH_GEMINI_API_KEY
  # Not exec'd, so the trap can delete the file when wrangler stops.
  "$WRANGLER" dev --port "$PORT" --env-file "$ENV_TMP"
fi
