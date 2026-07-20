#!/bin/bash
# Run the research_server (the /research AI Q&A backend) locally — one command, done.
#
# Usage:
#   ./scripts/research_server/run.sh              # wrangler dev (Workers runtime), auto-reload
#   ./scripts/research_server/run.sh --node       # plain Node entry — shows cpu=/build= debug timers
#   ./scripts/research_server/run.sh --port 8083  # override the port (default 8082)
#
# Dev port map: 8081 = Dart content server, 8082 = research server.
#
# Secrets live in research_server/.dev.vars (copy .dev.vars.example; live mode
# needs GEMINI_API_KEY + RESEARCH_STORE + RESEARCH_STUB=0). wrangler reads that
# file automatically; --node mode sources it before starting.

set -e

# --- Parse args -------------------------------------------------------------
PORT=8082
RUNTIME="wrangler"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) PORT="$2";      shift 2 ;;
    --node) RUNTIME="node"; shift ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: ./scripts/research_server/run.sh [--port 8082] [--node]"
      exit 1
      ;;
  esac
done

# Project root is two levels up: scripts/research_server/ -> scripts/ -> project.
cd "$(dirname "$0")/../.."
cd research_server

# wrangler needs Node >= 20; the system default may be older, so fall back to
# the newest nvm-installed Node.
NODE_MAJOR=$(node -v 2>/dev/null | sed 's/^v\([0-9]*\).*/\1/')
if [ "${NODE_MAJOR:-0}" -lt 20 ]; then
  NVM_BIN=$(ls -d "$HOME/.nvm/versions/node"/v*/bin 2>/dev/null | sort -V | tail -1)
  if [ -z "$NVM_BIN" ]; then
    echo "error: Node >= 20 required (found ${NODE_MAJOR:-none}) and no nvm install found."
    exit 1
  fi
  export PATH="$NVM_BIN:$PATH"
fi

if [ ! -f .dev.vars ]; then
  echo "error: research_server/.dev.vars not found — copy .dev.vars.example and set your key."
  exit 1
fi

[ -d node_modules ] || npm install

# Free the port so a re-run doesn't hit "address already in use" (wrangler dev
# and stale servers both linger). Kill, then wait until the port is genuinely
# released, escalating to SIGKILL — a fixed sleep is racy.
PIDS=$(lsof -ti:"$PORT" 2>/dev/null || true)
if [ -n "$PIDS" ]; then
  echo "Stopping process on port $PORT (PID: $PIDS)..."
  echo "$PIDS" | xargs kill 2>/dev/null || true
  for _ in $(seq 1 10); do
    sleep 0.5
    PIDS=$(lsof -ti:"$PORT" 2>/dev/null || true)
    [ -z "$PIDS" ] && break          # port free → done
    echo "$PIDS" | xargs kill -9 2>/dev/null || true
  done
fi

echo "Starting research_server on http://localhost:$PORT ($RUNTIME)"
echo "Health check: curl localhost:$PORT/health"
echo "Press Ctrl+C to stop"
echo ""

if [ "$RUNTIME" = "node" ]; then
  npm run build
  set -a; source .dev.vars; set +a
  PORT="$PORT" exec node dist/src/node.js
else
  exec npx wrangler dev --port "$PORT"
fi
