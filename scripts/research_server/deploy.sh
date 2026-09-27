#!/bin/bash
# Deploy the research_server (the /research AI Q&A backend) to Cloudflare Workers.
# One command, no GitHub: wrangler uploads the built bundle straight from this
# checkout. It answers at RESEARCH_BASE_URL (scripts/config/targets.env) because
# that domain is attached to the Worker in the dashboard, not by this script.
#
# Usage:
#   ./scripts/research_server/deploy.sh --prod           # test, build + deploy to prod
#   ./scripts/research_server/deploy.sh --prod --dry-run # test, build + validate, DON'T upload
#   ./scripts/research_server/deploy.sh [--dev]          # not set up: exits 3
#
#   --skip-tests       dry run only: don't run scripts/research_server/test.sh first
#   --yes              Skip the release confirmation (for CI)
#
# Status: dev=placeholder prod=live
#
# ONE WORKER, IN PROD. A Worker is paid, and anything paid lives in the prod
# (ops) account only; every build — dev web, local runs, mobile — calls this
# one. It only reads, so sharing it is safe. --dev says so and exits 3 before
# any test. A dev Worker later is a CLOUDFLARE_DEV_* deploy of the same config
# with its own domain and a RESEARCH_BASE_URL of its own.
#
# A release is cut from RESEARCH_PROD_BRANCH with a clean tree, is tagged with
# its commit (Worker versions list it), and ends by asking RESEARCH_BASE_URL
# /health (live, with a key). A dry run skips all three: it uploads nothing,
# so it runs from any branch, offline — scripts/release_all_dryrun.sh relies
# on that.
#
# Config is research_server/wrangler.jsonc (name, vars, placement); the domain
# is attached in the dashboard. The Worker's secrets come from
# scripts/config/secrets.env and are uploaded with every deploy
# (--secrets-file): RESEARCH_GEMINI_API_KEY as GEMINI_API_KEY. An empty one is
# left out of the upload, and a secret left out stays on the Worker as it is —
# so a key change is an edit to secrets.env plus a deploy. A key that can't
# open RESEARCH_STORE (wrangler.jsonc) stops the upload: both belong to one
# Google project, so they change together, in one deploy.
#
# Requires CLOUDFLARE_PROD_API_TOKEN + CLOUDFLARE_PROD_ACCOUNT_ID in
# scripts/config/secrets.env (a dry run needs neither).
# END-USAGE

set -e

. "$(dirname "$0")/../lib/common.sh"

# --- Parse args -------------------------------------------------------------
TARGET="dev"
DRY_RUN=false
SKIP_TESTS=false
ASSUME_YES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dev)        TARGET="dev";  shift ;;
    --prod)       TARGET="prod"; shift ;;
    --dry-run)    DRY_RUN=true;  shift ;;
    --skip-tests) SKIP_TESTS=true; shift ;;
    --yes|-y)     ASSUME_YES=true; shift ;;
    -h|--help)    usage ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Run with -h for help." >&2
      exit 1
      ;;
  esac
done

if [ "$TARGET" = "dev" ]; then
  echo "research_server --dev is not set up: the Worker is paid, so it lives in"
  echo "the prod account only and every build calls that one."
  echo "Deploy it with: ./scripts/research_server/deploy.sh --prod"
  exit 3
fi

# The typecheck in test.sh is the only one: wrangler strips types unchecked.
if [ "$SKIP_TESTS" = true ] && [ "$DRY_RUN" = false ]; then
  echo "error: --skip-tests is for a dry run only. A release always runs the tests." >&2
  exit 1
fi

URL=$(target RESEARCH_BASE_URL)
RELEASE_BRANCH=$(target RESEARCH_PROD_BRANCH)

cd "$WISDOM_ROOT"

# Before the tests, so a wrong branch, a wrong account or a key that can't open
# the store fails in seconds. Only for a real upload: a dry run sends nothing
# and stays offline. use_cloudflare loads Node and wrangler itself.
if [ "$DRY_RUN" = false ]; then
  require_release_commit "$RELEASE_BRANCH" || exit 1
  use_cloudflare prod || { echo "       Nothing uploaded." >&2; exit 1; }
  if ! check_research_store; then
    echo "       Nothing uploaded." >&2
    exit 1
  fi
else
  require_node22
  research_deps
fi

# --- Tests ------------------------------------------------------------------
# Without the deploy token: no test needs it.
if [ "$SKIP_TESTS" = false ]; then
  if ! env -u CLOUDFLARE_API_TOKEN -u CLOUDFLARE_ACCOUNT_ID \
      ./scripts/research_server/test.sh; then
    echo "" >&2
    echo "error: scripts/research_server/test.sh failed (summary above)." >&2
    echo "       Nothing uploaded." >&2
    exit 1
  fi
  echo ""
fi

# Every build calls this one Worker, so it asks once. --yes for CI.
if [ "$DRY_RUN" = false ] && [ "$ASSUME_YES" = false ]; then
  confirm_release "Deploy research_server to PRODUCTION ($CLOUDFLARE_ACCOUNT_LINE)?"
fi

cd research_server

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
  DEPLOY_ARGS=(--dry-run)
  echo "Dry run: building + validating research_server, NOT uploading."
else
  # The Worker version carries its commit, as a Pages deployment does. The
  # API caps a version message at 100 characters. `--flag=value`, so a subject
  # starting with `-` is not read as a flag.
  git_stamp
  DEPLOY_ARGS=(--tag="$GIT_SHA" --message="${GIT_MSG:0:100}")
  echo "Deploying research_server live (prod, $GIT_SHA) -> ${URL#https://}"
fi
echo ""

# Not exec'd, so the trap can delete the secrets file afterwards.
"$WRANGLER" deploy "${DEPLOY_ARGS[@]}" "${SECRETS_ARGS[@]}"

[ "$DRY_RUN" = true ] && exit 0

# --- After the upload: the Worker answers on its domain ----------------------
# Also proves the upload left the dashboard-attached domain in place, and that
# the Worker holds a Gemini key at all. An empty RESEARCH_GEMINI_API_KEY keeps
# the one it has, so this fails only for a new Worker or a deleted key.
echo ""
echo "Checking $URL/health..."
if ! expect_http "$URL/health"; then
  echo "       Uploaded. Every build calls this Worker; to go back, see" >&2
  echo "       Rollback in scripts/research_server/README.md." >&2
  exit 1
fi
HEALTH=$(printf '%s' "$HTTP_RESPONSE" | tr -d ' ')
if ! printf '%s' "$HEALTH" | grep -q '"mode":"live"'; then
  echo "error: uploaded, but $URL/health is not live. To go back, see" >&2
  echo "       Rollback in scripts/research_server/README.md." >&2
  exit 1
fi
if ! printf '%s' "$HEALTH" | grep -q '"key_configured":true'; then
  echo "error: uploaded, but the Worker has no Gemini key, so every /research" >&2
  echo "       call fails. Set RESEARCH_GEMINI_API_KEY and deploy again." >&2
  exit 1
fi
echo "OK: $URL/health is live, with a key."
