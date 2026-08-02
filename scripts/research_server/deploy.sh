#!/bin/bash
# Deploy the research_server (the /research AI Q&A backend) to Cloudflare Workers.
# One command — pushes live to https://wisdom-research.bk-anigha.workers.dev with
# NO GitHub and NO commit (wrangler uploads the built bundle directly).
#
# Usage:
#   ./scripts/research_server/deploy.sh              # build + deploy live
#   ./scripts/research_server/deploy.sh --dry-run    # build + validate only, DON'T upload
#
# Config is research_server/wrangler.jsonc (name, vars, placement). The
# GEMINI_API_KEY is a Cloudflare *secret*, set once via `wrangler secret put` — it
# lives on Cloudflare and persists across deploys, so this script never sees it or
# needs it. Re-run `wrangler secret put GEMINI_API_KEY` only if the key changes.
#
# Requires `wrangler login` done once (CLI auth — separate from dashboard sign-in).

set -e

# --- Parse args -------------------------------------------------------------
DRY_RUN=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN="--dry-run"; shift ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: ./scripts/research_server/deploy.sh [--dry-run]"
      exit 1
      ;;
  esac
done

# Project root is two levels up: scripts/research_server/ -> scripts/ -> project.
cd "$(dirname "$0")/../.."
cd research_server

# wrangler 4.112 requires Node >= 22 (its package.json `engines`); the system
# default may be older, so fall back to the newest nvm-installed Node and then
# re-check, because the newest installed one may still be too old.
# (Same guard as run.sh and scripts/static_site/deploy.sh.)
NODE_MAJOR=$(node -v 2>/dev/null | sed 's/^v\([0-9]*\).*/\1/')
if [ "${NODE_MAJOR:-0}" -lt 22 ]; then
  NVM_BIN=$(ls -d "$HOME/.nvm/versions/node"/v*/bin 2>/dev/null | sort -V | tail -1)
  [ -n "$NVM_BIN" ] && export PATH="$NVM_BIN:$PATH"
  NODE_MAJOR=$(node -v 2>/dev/null | sed 's/^v\([0-9]*\).*/\1/')
  if [ "${NODE_MAJOR:-0}" -lt 22 ]; then
    echo "error: wrangler needs Node >= 22 (found ${NODE_MAJOR:-none})." >&2
    echo "       Install one, e.g. \`nvm install 22\`." >&2
    exit 1
  fi
fi

[ -d node_modules ] || npm install

if [ -n "$DRY_RUN" ]; then
  echo "Dry run: building + validating research_server, NOT uploading."
else
  echo "Deploying research_server live -> wisdom-research.bk-anigha.workers.dev"
fi
echo ""

exec npx wrangler deploy $DRY_RUN
