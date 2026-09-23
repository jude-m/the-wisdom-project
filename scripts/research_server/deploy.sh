#!/bin/bash
# Deploy the research_server (the /research AI Q&A backend) to Cloudflare Workers.
# One command — pushes live to RESEARCH_BASE_URL (scripts/config/targets.env)
# with NO GitHub and NO commit (wrangler uploads the built bundle directly).
#
# Usage:
#   ./scripts/research_server/deploy.sh              # test, build + deploy to dev
#   ./scripts/research_server/deploy.sh --dev        # the same, said out loud
#   ./scripts/research_server/deploy.sh --prod       # not set up yet: exits 3
#   ./scripts/research_server/deploy.sh --dry-run    # test, build + validate, DON'T upload
#
#   --skip-tests       dev: don't run scripts/research_server/test.sh first
#   --yes              Skip a release confirmation (--prod only, for CI)
#
# DEV IS TODAY'S ONLY WORKER, on the personal account (`wrangler login`). Prod
# moves to the ops account (docs/todo/web-strategy/web-release.md §4); until
# then --prod says so and exits 3 before any test, so nothing reads it as a
# release.
#
# Config is research_server/wrangler.jsonc (name, vars, placement). The Worker's
# secrets come from scripts/config/secrets.env and are uploaded with every
# deploy (--secrets-file): RESEARCH_GEMINI_API_KEY as GEMINI_API_KEY. An empty
# one is left out of the upload, and a secret left out stays on the Worker as it
# is — so a key change is an edit to secrets.env plus a deploy.
#
# Requires `wrangler login` done once (CLI auth — separate from dashboard sign-in).
# END-USAGE

set -e

. "$(dirname "$0")/../lib/common.sh"

# --- Parse args -------------------------------------------------------------
TARGET="dev"
DRY_RUN=false
SKIP_TESTS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dev)        TARGET="dev";  shift ;;
    --prod)       TARGET="prod"; shift ;;
    --dry-run)    DRY_RUN=true;  shift ;;
    --skip-tests) SKIP_TESTS=true; shift ;;
    --yes|-y)     shift ;;
    -h|--help)    usage ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Run with -h for help." >&2
      exit 1
      ;;
  esac
done

if [ "$TARGET" = "prod" ]; then
  echo "research_server --prod is not set up yet: the Worker's production home is"
  echo "the ops account, and it has not moved there (web-release.md §4)."
  echo "Today's only Worker is dev: ./scripts/research_server/deploy.sh --dev"
  exit 3
fi

URL=$(target RESEARCH_BASE_URL)

cd "$WISDOM_ROOT"

# --- Tests ------------------------------------------------------------------
if [ "$SKIP_TESTS" = false ]; then
  if ! ./scripts/research_server/test.sh; then
    echo "" >&2
    echo "error: scripts/research_server/test.sh failed (summary above)." >&2
    echo "       Nothing uploaded." >&2
    exit 1
  fi
  echo ""
fi

cd research_server

require_node22
research_deps

# Secrets only for a real upload: a dry run uploads nothing, so it needs none
# and keeps working on a checkout with no secrets.env.
SECRETS_ARGS=()
if [ "$DRY_RUN" = false ]; then
  SECRETS_TMP=$(mktemp "${TMPDIR:-/tmp}/wisdom-research-secrets.XXXXXX")
  trap 'rm -f "$SECRETS_TMP"' EXIT
  write_worker_secrets "$SECRETS_TMP" GEMINI_API_KEY=RESEARCH_GEMINI_API_KEY
  if [ -s "$SECRETS_TMP" ]; then
    SECRETS_ARGS=(--secrets-file "$SECRETS_TMP")
    echo "Secrets uploaded with this deploy: $(sed 's/=.*//' "$SECRETS_TMP" | tr '\n' ' ')"
  else
    echo "No research secrets set (environment or scripts/config/secrets.env) —"
    echo "the Worker keeps the ones it has."
  fi
fi

if [ "$DRY_RUN" = true ]; then
  DRY_RUN_ARGS=(--dry-run)
  echo "Dry run: building + validating research_server, NOT uploading."
else
  DRY_RUN_ARGS=()
  echo "Deploying research_server live (dev) -> ${URL#https://}"
fi
echo ""

# Not exec'd, so the trap can delete the secrets file afterwards.
"$WRANGLER" deploy "${DRY_RUN_ARGS[@]}" "${SECRETS_ARGS[@]}"
