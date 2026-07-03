#!/bin/bash
# Run the research_server (the /research AI Q&A backend) locally — one command, done.
#
# Usage:
#   ./scripts/research_server/run.sh              # live mode, reads .env, auto-reload
#   ./scripts/research_server/run.sh --port 8082  # override the port (default 8081)
#   ./scripts/research_server/run.sh --no-reload  # disable file-watch auto-reload
#
# What it does:
# 1. Frees the port (kills any server still holding it) so you can just re-run
#    without the "address already in use" error.
# 2. Starts uvicorn with --env-file so GEMINI_API_KEY / RESEARCH_STORE / RESEARCH_STUB are
#    read straight from research_server/.env — the app reads os.environ directly and
#    does NOT auto-load .env on its own.
# 3. Enables --reload so editing any .py restarts the server automatically —
#    launch once and forget (pass --no-reload to turn that off).
#
# Live answers need RESEARCH_STUB=0 + GEMINI_API_KEY + RESEARCH_STORE in research_server/.env
# (copy .env.example). See research_server/README.md.

set -e

# --- Parse args -------------------------------------------------------------
PORT=8081
RELOAD="--reload"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)      PORT="$2"; shift 2 ;;
    --no-reload) RELOAD="";  shift ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: ./scripts/research_server/run.sh [--port 8081] [--no-reload]"
      exit 1
      ;;
  esac
done

# Project root is two levels up: scripts/research_server/ -> scripts/ -> project.
cd "$(dirname "$0")/../.."
cd research_server

# .env must exist — uvicorn --env-file loads the key/store from it (the app
# itself does not read .env, only os.environ).
if [ ! -f .env ]; then
  echo "error: research_server/.env not found — copy .env.example and set your key."
  exit 1
fi

# Use the project venv's uvicorn (built per README §Go live).
UVICORN=".venv/bin/uvicorn"
if [ ! -x "$UVICORN" ]; then
  echo "error: $UVICORN not found — create the venv first:"
  echo "  cd research_server && python3 -m venv .venv && source .venv/bin/activate \\"
  echo "    && pip install -r requirements.txt"
  exit 1
fi

# Free the port so a re-run doesn't hit "address already in use".
PIDS=$(lsof -ti:"$PORT" 2>/dev/null || true)
if [ -n "$PIDS" ]; then
  echo "Stopping process on port $PORT (PID: $PIDS)..."
  echo "$PIDS" | xargs kill 2>/dev/null || true
  sleep 1
fi

echo "Starting research_server on http://localhost:$PORT (env: .env${RELOAD:+, auto-reload})"
echo "Health check: curl localhost:$PORT/health"
echo "Press Ctrl+C to stop"
echo ""

exec "$UVICORN" app.main:app --host 127.0.0.1 --port "$PORT" --env-file .env $RELOAD
