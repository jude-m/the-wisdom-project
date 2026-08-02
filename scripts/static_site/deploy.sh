#!/bin/bash
# Build the static HTML site and push it to Cloudflare Pages — one command.
#
# Direct upload: wrangler sends the built directory straight to Cloudflare, with
# NO GitHub and NO commit. It consumes none of the free plan's 500 builds/month,
# and uploads are hash-incremental, so after the first deploy only genuinely
# changed pages transfer (which is what the generator's byte-determinism buys —
# build plan §11.8). This is the same path the planned GitHub Action takes, just
# driven by hand (docs/todo/web-strategy/static-web-hosting.md, "Build & deploy
# pipeline").
#
# Usage:
#   ./scripts/static_site/deploy.sh                        # whole corpus -> dev
#   ./scripts/static_site/deploy.sh --dev                  # the same, said out loud
#   ./scripts/static_site/deploy.sh --prod                 # -> the production account
#   ./scripts/static_site/deploy.sh --root an-1,atta-an-1  # one subtree + its commentary
#   ./scripts/static_site/deploy.sh --skip-build           # upload build/ as-is
#   ./scripts/static_site/deploy.sh --dry-run              # build + check, DON'T upload
#
#   --project <name>   Pages project     (or $CF_PAGES_PROJECT; overrides the target)
#   --branch <name>    Deployment branch (overrides the target)
#   --yes              Skip the --prod confirmation prompt (for CI)
#
# TWO ACCOUNTS, TWO PROJECTS. Dev lives in the personal Cloudflare account, prod
# in the wisdom.ops one, so a handover can transfer prod alone. A Pages project
# belongs to exactly ONE account, and `<project>.pages.dev` is a single GLOBAL
# first-come namespace — so the two environments cannot share a base name. The
# `-dev` suffix is forced by that topology, not decoration.
#
#   dev    personal account, `wrangler login`        sammaditthi-dev, branch dev
#          -> dev.sammaditthi-dev.pages.dev          (preview)
#   prod   ops account, API token in .prod.env       $CF_PAGES_PROJECT_PROD, branch main
#          -> <project>.pages.dev                    (production, later a custom domain)
#
# PREVIEW BY DEFAULT, ON PURPOSE. Cloudflare adds `X-Robots-Tag: noindex` to
# every *preview* deployment; a production one carries no such header and is
# crawlable. A dev copy of the canon getting indexed would compete with the real
# site for the exact queries the whole static-site effort exists to win — so dev
# deploys to a preview branch, and the banner below shouts if that ever changes.
#
# Requires `wrangler login` done once for dev (CLI auth — separate from the
# dashboard sign-in), and scripts/static_site/.prod.env for prod (copy
# .prod.env.example). The first run against a new project offers to create it;
# that is expected.
# END-USAGE

set -e

# --- Config -----------------------------------------------------------------
DEV_PROJECT="${CF_PAGES_PROJECT:-sammaditthi-dev}"
DEV_BRANCH="dev"
PRODUCTION_BRANCH="main"
PROD_ENV_FILE="scripts/static_site/.prod.env"

# Cloudflare Pages refuses a project with more than this many files. The whole
# corpus is ~14.8 K today and its size is fixed by the canon, but the P5 gate may
# add 1,603 grouped-leaf stubs — checked here so an over-cap build fails in a
# second with a number, instead of part-way through a 212 MB upload.
readonly MAX_FILES=20000

TARGET="dev"
ROOTS="all"
SKIP_BUILD=false
DRY_RUN=false
ASSUME_YES=false
PROJECT_OVERRIDE=""
BRANCH_OVERRIDE=""

# --- Parse args -------------------------------------------------------------
usage() {
  sed -n '2,/^# END-USAGE$/p' "$0" | sed 's/^# \{0,1\}//; /^END-USAGE$/d'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dev)        TARGET="dev";  shift ;;
    --prod)       TARGET="prod"; shift ;;
    --root)       ROOTS="$2";             shift 2 ;;
    --project)    PROJECT_OVERRIDE="$2";  shift 2 ;;
    --branch)     BRANCH_OVERRIDE="$2";   shift 2 ;;
    --skip-build) SKIP_BUILD=true;  shift ;;
    --dry-run)    DRY_RUN=true;     shift ;;
    --yes|-y)     ASSUME_YES=true;  shift ;;
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
OUT="static_site_generator/build"

# --- Resolve the target -----------------------------------------------------
# Prod credentials come from .prod.env as environment variables, which is how
# wrangler selects an account non-interactively (CLOUDFLARE_API_TOKEN +
# CLOUDFLARE_ACCOUNT_ID override the `wrangler login` session). That keeps the
# personal login untouched, and it is the same mechanism the GitHub Action will
# use via repo secrets — so the CI path later is this path, not a rewrite.
if [ "$TARGET" = "prod" ]; then
  if [ ! -f "$PROD_ENV_FILE" ]; then
    echo "error: $PROD_ENV_FILE not found." >&2
    echo "       cp ${PROD_ENV_FILE}.example $PROD_ENV_FILE and fill it in." >&2
    exit 1
  fi

  # `set -a` exports everything the file defines, so wrangler inherits it.
  set -a
  # shellcheck source=/dev/null
  . "$PROD_ENV_FILE"
  set +a

  # The production project name is deliberately NOT defaulted here. Its name is
  # still an open question (static-web-hosting.md, open-Q #2) and it must be
  # created from the ops account — a Pages project cannot move between accounts,
  # so a guessed name created from the wrong login would have to be deleted,
  # briefly freeing it to anyone. Better to fail than to invent one.
  : "${CF_PAGES_PROJECT_PROD:?not set in $PROD_ENV_FILE — name the production Pages project}"
  : "${CLOUDFLARE_API_TOKEN:?not set in $PROD_ENV_FILE — create one in the ops account}"
  : "${CLOUDFLARE_ACCOUNT_ID:?not set in $PROD_ENV_FILE — the ops account ID}"

  PROJECT="$CF_PAGES_PROJECT_PROD"
  BRANCH="$PRODUCTION_BRANCH"
else
  PROJECT="$DEV_PROJECT"
  BRANCH="$DEV_BRANCH"

  # A token exported in the calling shell silently outranks `wrangler login`, so
  # a stray one could push dev content into the production account. Warn rather
  # than block: using a scoped dev token instead of the login is legitimate.
  if [ -n "${CLOUDFLARE_API_TOKEN:-}" ]; then
    echo "warning: CLOUDFLARE_API_TOKEN is set in this shell and overrides your" >&2
    echo "         wrangler login. Confirm the account below is the dev one." >&2
    echo "" >&2
  fi
fi

[ -n "$PROJECT_OVERRIDE" ] && PROJECT="$PROJECT_OVERRIDE"
[ -n "$BRANCH_OVERRIDE" ]  && BRANCH="$BRANCH_OVERRIDE"

# --- Release guards (prod only) ---------------------------------------------
# Direct upload has no Git integration: merging to main deploys nothing, and
# --branch is only a label. Nothing therefore ties a release to the state of the
# repo unless it is checked here.
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
git diff --quiet 2>/dev/null && DIRTY=false || DIRTY=true

if [ "$TARGET" = "prod" ]; then
  if [ "$GIT_BRANCH" != "$PRODUCTION_BRANCH" ]; then
    echo "error: --prod must run from '$PRODUCTION_BRANCH' (on '$GIT_BRANCH')." >&2
    echo "       Merge first, then release." >&2
    exit 1
  fi
  if [ "$DIRTY" = true ]; then
    echo "error: working tree is dirty — a release must be reproducible from a commit." >&2
    git status --short >&2
    exit 1
  fi
fi

# --- Build ------------------------------------------------------------------
if [ "$SKIP_BUILD" = false ]; then
  echo "Building static site (--root $ROOTS)..."
  dart run static_site_generator/bin/generate.dart --root "$ROOTS"
  echo ""
elif [ ! -d "$OUT" ]; then
  echo "error: --skip-build given but $OUT does not exist. Build once first." >&2
  exit 1
fi

# --- Preflight --------------------------------------------------------------
FILE_COUNT=$(find "$OUT" -type f | wc -l | tr -d ' ')
if [ "$FILE_COUNT" -gt "$MAX_FILES" ]; then
  echo "error: $FILE_COUNT files in $OUT — over Cloudflare Pages' $MAX_FILES" >&2
  echo "       per-project cap. Nothing uploaded." >&2
  exit 1
fi

# Single-file cap is 25 MiB. The largest page in the corpus is ~1 MB, so this
# only fires if something unexpected lands in the output — but "unexpected" is
# precisely the case worth catching before a long upload.
BIG=$(find "$OUT" -type f -size +25M | head -1)
if [ -n "$BIG" ]; then
  echo "error: $BIG exceeds Cloudflare Pages' 25 MiB per-file limit." >&2
  exit 1
fi

echo "target     $TARGET"
echo "files      $FILE_COUNT / $MAX_FILES   ($(du -sh "$OUT" | awk '{print $1}'))"
echo "project    $PROJECT"
if [ "$BRANCH" = "$PRODUCTION_BRANCH" ]; then
  echo "branch     $BRANCH   ** PRODUCTION — this deployment is INDEXABLE **"
  echo "url        https://$PROJECT.pages.dev"
else
  echo "branch     $BRANCH   (preview — Cloudflare adds X-Robots-Tag: noindex)"
  echo "url        https://$BRANCH.$PROJECT.pages.dev"
fi
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "Dry run: built and checked, NOT uploading."
  exit 0
fi

# A release is public and hard to walk back, so it asks once. --yes for CI.
if [ "$TARGET" = "prod" ] && [ "$ASSUME_YES" = false ]; then
  if [ ! -t 0 ]; then
    echo "error: --prod needs a terminal to confirm. Pass --yes in automation." >&2
    exit 1
  fi
  read -r -p "Release the canon to PRODUCTION ($PROJECT)? [y/N] " REPLY
  case "$REPLY" in
    y|Y|yes|YES) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
  echo ""
fi

# --- wrangler ---------------------------------------------------------------
# wrangler needs Node >= 20; the system default may be older, so fall back to
# the newest nvm-installed Node. (Same guard as scripts/research_server/*.sh.)
NODE_MAJOR=$(node -v 2>/dev/null | sed 's/^v\([0-9]*\).*/\1/')
if [ "${NODE_MAJOR:-0}" -lt 20 ]; then
  NVM_BIN=$(ls -d "$HOME/.nvm/versions/node"/v*/bin 2>/dev/null | sort -V | tail -1)
  if [ -z "$NVM_BIN" ]; then
    echo "error: Node >= 20 required (found ${NODE_MAJOR:-none}) and no nvm install found." >&2
    exit 1
  fi
  export PATH="$NVM_BIN:$PATH"
fi

# Prefer research_server's installed wrangler over an npx download: it is the
# only pinned copy in the repo (package.json, ^4.0.0), so the two Cloudflare
# surfaces deploy with one version. The static site has no package.json of its
# own on purpose — it is a Dart generator with no Node dependencies, and
# wrangler is a CLI it invokes, not something it builds against.
WRANGLER="research_server/node_modules/.bin/wrangler"
if [ ! -x "$WRANGLER" ]; then
  WRANGLER="npx --yes wrangler@4"
fi

# Stamp the deployment so the Pages dashboard says which commit produced it.
# --commit-dirty is passed explicitly because uncommitted work is normal on dev;
# a prod release is already guaranteed clean by the guard above.
GIT_SHA=$(git rev-parse --short HEAD)
GIT_MSG=$(git log -1 --pretty=%s)

echo "Deploying $OUT -> Cloudflare Pages ($PROJECT, branch $BRANCH)"
echo ""

exec $WRANGLER pages deploy "$OUT" \
  --project-name="$PROJECT" \
  --branch="$BRANCH" \
  --commit-hash="$GIT_SHA" \
  --commit-message="$GIT_MSG" \
  --commit-dirty="$DIRTY"
