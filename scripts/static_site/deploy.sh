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
#   ./scripts/static_site/deploy.sh --prod                 # release to production
#   ./scripts/static_site/deploy.sh --root an-1,atta-an-1  # dev: one subtree + commentary
#   ./scripts/static_site/deploy.sh --skip-build           # dev: upload build/ as-is
#   ./scripts/static_site/deploy.sh --dry-run              # build + check, DON'T upload
#
#   --yes              Skip the release confirmation prompt (--prod only, for CI)
#
# EXACTLY TWO TARGETS, ONE PER ACCOUNT — and no third path. There is no --branch
# and no --project: each target's account, project and branch are fixed together
# in the config block below, so the three can never disagree with each other.
#
#   dev    personal account, `wrangler login`    sammaditthi-dev, branch dev
#          -> dev.sammaditthi-dev.pages.dev      (preview, noindex)
#   prod   ops account, .prod.env token          sammaditthi,     branch main
#          -> sammaditthi.pages.dev              (production, INDEXABLE)
#
# Dev and prod are separate Cloudflare ACCOUNTS — prod under wisdom.ops so a
# handover can transfer prod alone. A Pages project belongs to exactly ONE
# account, and `<project>.pages.dev` is a single GLOBAL first-come namespace, so
# the two environments cannot share a base name. The `-dev` suffix is topology,
# not decoration.
#
# PREVIEW ON DEV, ON PURPOSE. Cloudflare adds `X-Robots-Tag: noindex` to every
# *preview* deployment; a production one carries no such header and is crawlable.
# A dev copy of the canon getting indexed would compete with the real site for
# the exact queries the whole static-site effort exists to win — so dev deploys
# to a preview branch and prod is the only indexable target.
#
# BUILD OPTIONS ARE DEV-ONLY. Direct upload REPLACES the whole deployment, so a
# `--root` subtree or a stale `build/` shipped to prod does not add a partial
# site — it takes the full canon offline. A release always rebuilds everything.
#
# Both Pages projects already exist, each created with `--production-branch
# main`. If one ever has to be recreated, create it explicitly from the owning
# account — `wrangler pages project create <name> --production-branch main` —
# and never by letting `pages deploy` prompt for it: that prompt defaults to
# whatever git branch you happen to be on, and getting it wrong silently swaps
# which deployments are indexable and which are noindex.
#
# Requires `wrangler login` done once for dev (CLI auth — separate from the
# dashboard sign-in), and scripts/static_site/.prod.env for prod (copy
# .prod.env.example).
# END-USAGE

set -e

# --- Config -----------------------------------------------------------------
# Fixed per target, deliberately not overridable. An account, a project and a
# branch that can only ever be right or wrong together is the whole design.
DEV_PROJECT="sammaditthi-dev"
DEV_BRANCH="dev"
PROD_PROJECT="sammaditthi"
PROD_BRANCH="main"
PROD_ENV_FILE="scripts/static_site/.prod.env"

# $PROD_BRANCH does double duty: it is both the Pages branch a release deploys
# to and the git branch a release must be cut from. They are the same name
# because they describe the same thing — what is live.

# wrangler caches resolved accounts per repo in .wrangler/cache. Two files live
# there and they behave differently, which is worth writing down because the
# difference is the entire reason this script clears one and not the other:
#
#   pages.json             written by `pages deploy` as {account_id, project_name}
#                          and read back as `config.account_id`. CLOUDFLARE_ACCOUNT_ID
#                          outranks it (wrangler 4.112 merges the env var over the
#                          cache), so it cannot misroute a --prod run. But DEV sets
#                          no such variable, so on the dev path this cache IS the
#                          answer — and left behind by a prod deploy it points dev
#                          straight at the ops account. Cleared before and after
#                          every run for exactly that reason.
#
#   wrangler-account.json  the `wrangler login` account. Consulted only when there
#                          is no env var and no pages.json — which is precisely the
#                          dev path, where it is the RIGHT answer. Deliberately
#                          left alone.
PAGES_ACCOUNT_CACHE=".wrangler/cache/pages.json"

# Cloudflare Pages refuses a project with more than this many files. The whole
# corpus is ~14.8 K today and its size is fixed by the canon, but the P5 gate may
# add 1,603 grouped-leaf stubs — checked here so an over-cap build fails in a
# second with a number, instead of part-way through a 212 MB upload.
readonly MAX_FILES=20000

TARGET="dev"
ROOTS="all"
ROOTS_SET=false
SKIP_BUILD=false
DRY_RUN=false
ASSUME_YES=false

# --- Parse args -------------------------------------------------------------
usage() {
  sed -n '2,/^# END-USAGE$/p' "$0" | sed 's/^# \{0,1\}//; /^END-USAGE$/d'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dev)        TARGET="dev";  shift ;;
    --prod)       TARGET="prod"; shift ;;
    --root)
      # Checked rather than left to `shift 2`, which fails under `set -e` and
      # kills the script with no message at all — a silent exit 1 reads like a
      # crash, not a typo.
      if [ -z "${2:-}" ]; then
        echo "error: --root needs a value, e.g. --root an-1,atta-an-1 (or 'all')." >&2
        exit 1
      fi
      ROOTS="$2"; ROOTS_SET=true;  shift 2 ;;
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
EXPECTED_ACCOUNT=""
if [ "$TARGET" = "prod" ]; then
  # Refuse the build shortcuts before anything else happens. Both would publish
  # something other than "the whole corpus at this commit", and because direct
  # upload replaces the entire deployment, the result is not a partial addition
  # but a partial *site* — the rest of the canon simply stops existing.
  if [ "$ROOTS_SET" = true ]; then
    echo "error: --root is dev-only. A release is always the whole corpus." >&2
    exit 1
  fi
  if [ "$SKIP_BUILD" = true ]; then
    echo "error: --skip-build is dev-only. A release always rebuilds, so what" >&2
    echo "       ships is what the commit produces — not whatever build/ holds" >&2
    echo "       from the last dev test." >&2
    exit 1
  fi

  if [ ! -f "$PROD_ENV_FILE" ]; then
    echo "error: $PROD_ENV_FILE not found." >&2
    echo "       cp ${PROD_ENV_FILE}.example $PROD_ENV_FILE and fill it in." >&2
    exit 1
  fi

  # Prod credentials arrive as environment variables, which is how wrangler
  # selects an account non-interactively. It is also what the planned GitHub
  # Action will use via repo secrets, so CI later is this path rather than a
  # rewrite — and it leaves the personal `wrangler login` untouched.
  #
  # `set -a` exports everything the file defines, so wrangler inherits it. The
  # file may fetch the token from a secret store rather than hold it literally,
  # which is why it is sourced rather than parsed.
  set -a
  # shellcheck source=/dev/null
  . "$PROD_ENV_FILE"
  set +a

  : "${CLOUDFLARE_API_TOKEN:?not set in $PROD_ENV_FILE — create one in the ops account}"
  : "${CLOUDFLARE_ACCOUNT_ID:?not set in $PROD_ENV_FILE — the ops account ID}"

  # The project name is fixed in this script now rather than read from .prod.env.
  # An older copy of that file still naming one is a stale config, not a second
  # opinion — say so instead of ignoring it.
  if [ -n "${CF_PAGES_PROJECT_PROD:-}" ] && [ "$CF_PAGES_PROJECT_PROD" != "$PROD_PROJECT" ]; then
    echo "error: $PROD_ENV_FILE sets CF_PAGES_PROJECT_PROD=$CF_PAGES_PROJECT_PROD," >&2
    echo "       but this script deploys to '$PROD_PROJECT'. Delete that line." >&2
    exit 1
  fi

  PROJECT="$PROD_PROJECT"
  BRANCH="$PROD_BRANCH"
  EXPECTED_ACCOUNT="$CLOUDFLARE_ACCOUNT_ID"
else
  PROJECT="$DEV_PROJECT"
  BRANCH="$DEV_BRANCH"

  # Dev authenticates by `wrangler login` and nothing else. An API token exported
  # in the calling shell silently outranks that login, and the way it goes wrong
  # is not a clean failure: pointed at the ops account, an interactive wrangler
  # would OFFER TO CREATE `sammaditthi-dev` there, quietly undoing the account
  # separation this whole layout exists to keep. Refuse rather than warn — the
  # fix is a fresh shell, which costs nothing.
  if [ -n "${CLOUDFLARE_API_TOKEN:-}" ] || [ -n "${CLOUDFLARE_ACCOUNT_ID:-}" ]; then
    echo "error: CLOUDFLARE_API_TOKEN/CLOUDFLARE_ACCOUNT_ID are set in this shell" >&2
    echo "       and would override your wrangler login, aiming dev at whichever" >&2
    echo "       account that token belongs to." >&2
    echo "       Dev deploys with \`wrangler login\` only — start a fresh shell." >&2
    exit 1
  fi
fi

# --- Release guards (prod only) ---------------------------------------------
# Direct upload has no Git integration: merging to main deploys nothing, and the
# branch name is only a label. Nothing therefore ties a release to the state of
# the repo unless it is checked right here.
#
# `git status --porcelain` rather than `git diff`, so staged AND untracked files
# both count. A never-added template is invisible to `git diff` yet very much
# part of the build, and stamping such a deployment --commit-dirty=false would
# attribute it to a commit that cannot reproduce it. build/ is gitignored, so
# the generator's own output does not trip this.
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
  DIRTY=false
else
  DIRTY=true
fi

if [ "$TARGET" = "prod" ]; then
  if [ "$GIT_BRANCH" != "$PROD_BRANCH" ]; then
    echo "error: a release must be cut from '$PROD_BRANCH' (on '$GIT_BRANCH')." >&2
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
else
  if [ ! -d "$OUT" ]; then
    echo "error: --skip-build given but $OUT does not exist. Build once first." >&2
    exit 1
  fi
  # --root only reaches the generator, so pairing it with --skip-build asks for
  # a subtree and silently uploads whatever the last build happened to produce.
  if [ "$ROOTS_SET" = true ]; then
    echo "warning: --root is ignored with --skip-build; uploading $OUT as it stands." >&2
    echo "" >&2
  fi
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

# --- wrangler + account check -----------------------------------------------
# Skipped entirely on a dry run: --dry-run means build and check, so it should
# keep working with no network and no auth, the way it did before this section
# moved above the banner.
ACCOUNT_LINE="(not checked — dry run)"
if [ "$DRY_RUN" = false ]; then
  # wrangler 4.112 requires Node >= 22 (its package.json `engines`); the system
  # default may be older, so fall back to the newest nvm-installed Node and then
  # re-check, because the newest installed one may still be too old.
  # (Same guard as scripts/research_server/*.sh.)
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

  # research_server's pinned wrangler (package.json, ^4.0.0) is the only copy in
  # the repo, so both Cloudflare surfaces deploy with one version. Install it the
  # way research_server's own scripts do rather than falling back to an `npx`
  # download, which would fetch whatever 4.x happens to be newest today and quietly
  # break that guarantee. The static site has no package.json of its own on purpose
  # — it is a Dart generator with no Node dependencies, and wrangler is a CLI it
  # invokes, not something it builds against.
  WRANGLER="research_server/node_modules/.bin/wrangler"
  if [ ! -x "$WRANGLER" ]; then
    echo "Installing research_server dependencies (for wrangler)..."
    npm install --prefix research_server
    echo ""
  fi

  # Drop the stale account cache BEFORE wrangler is asked anything, so the account
  # is resolved from this run's credentials and not from the last run's target.
  rm -f "$PAGES_ACCOUNT_CACHE"

  # Show which Cloudflare account is actually about to receive the upload, and for
  # prod insist it is the one .prod.env names. Two accounts only buy separation if
  # something checks.
  #
  # --json, not the human table: that table is drawn with box characters which
  # pick up ANSI colour whenever wrangler thinks the output wants it, and the
  # account name then parses out empty. The announcement is not decoration — this
  # call reaches the network, and without it a slow or unreachable API looks like
  # the script having hung before doing anything at all.
  echo "Checking Cloudflare account..."
  ACCOUNT_JSON=$("$WRANGLER" whoami --json 2>/dev/null || true)
  ACCOUNT_IDS=$(printf '%s' "$ACCOUNT_JSON" \
    | grep -oE '"id" *: *"[0-9a-f]{32}"' | grep -oE '[0-9a-f]{32}' \
    | sort -u | tr '\n' ' ' || true)
  ACCOUNT_NAME=$(printf '%s' "$ACCOUNT_JSON" \
    | grep -oE '"name" *: *"[^"]*"' | head -1 | sed -E 's/.*: *"//; s/"$//' || true)

  if [ -z "$ACCOUNT_IDS" ]; then
    # Could not verify — not the same thing as verified wrong, and it must not
    # read like it. Usually an expired token, a token missing the
    # `Account Settings: Read` permission it needs to list accounts at all, or
    # simply no network.
    if [ "$TARGET" = "prod" ]; then
      echo "error: could not verify the Cloudflare account — \`wrangler whoami\`" >&2
      echo "       returned nothing. Likely the $PROD_ENV_FILE token is expired," >&2
      echo "       or is missing the 'Account Settings: Read' permission." >&2
      echo "       Refusing to upload to production unverified." >&2
      exit 1
    fi
    echo "warning: could not verify the Cloudflare account (whoami failed)." >&2
    echo "" >&2
  elif [ -n "$EXPECTED_ACCOUNT" ]; then
    case " $ACCOUNT_IDS " in
      *" $EXPECTED_ACCOUNT "*) ;;
      *)
        echo "error: wrangler resolved account(s) [$ACCOUNT_IDS]," >&2
        echo "       but $PROD_ENV_FILE names $EXPECTED_ACCOUNT." >&2
        echo "       Refusing to upload — check CLOUDFLARE_API_TOKEN and" >&2
        echo "       CLOUDFLARE_ACCOUNT_ID." >&2
        exit 1
        ;;
    esac
  fi

  ACCOUNT_LINE="${ACCOUNT_NAME:-unknown}   (${ACCOUNT_IDS:-unresolved})"
  echo ""
fi

if [ "$TARGET" = "prod" ]; then
  ORIGIN="https://$PROJECT.pages.dev"
else
  ORIGIN="https://$BRANCH.$PROJECT.pages.dev"
fi

# `url` below is the ORIGIN, and that is now the URL to smoke-test on every
# build shape. Before the landing page (build plan P3) it was a 404, and so was
# the obvious next guess `/<nodeKey>` — every page lives under `/tipitaka/` — so
# this printed a hand-picked entry key read out of the output directory instead.
# `/` is a real page now, and the generator builds it from the roots it actually
# wrote, so a `--root an-1` deploy's origin links only into that subtree. The
# rule that block existed for still holds: a deploy you cannot smoke-test by
# clicking the URL it just printed is a deploy you have not checked.

echo "target     $TARGET"
echo "account    $ACCOUNT_LINE"
echo "files      $FILE_COUNT / $MAX_FILES   ($(du -sh "$OUT" | awk '{print $1}'))"
echo "project    $PROJECT"
if [ "$TARGET" = "prod" ]; then
  echo "branch     $BRANCH   ** PRODUCTION — this deployment is INDEXABLE **"
else
  echo "branch     $BRANCH   (preview — Cloudflare adds X-Robots-Tag: noindex)"
fi
echo "url        $ORIGIN"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "Dry run: built and checked, NOT uploading."
  exit 0
fi

# A release is public and hard to walk back, so it asks once. --yes for CI.
if [ "$TARGET" = "prod" ] && [ "$ASSUME_YES" = false ]; then
  if [ ! -t 0 ]; then
    echo "error: a release needs a terminal to confirm. Pass --yes in automation." >&2
    exit 1
  fi
  read -r -p "Release the canon to PRODUCTION ($PROJECT)? [y/N] " REPLY
  case "$REPLY" in
    y|Y|yes|YES) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
  echo ""
fi

# Stamp the deployment so the Pages dashboard says which commit produced it.
# --commit-dirty is passed explicitly because uncommitted work is normal on dev;
# a release is already guaranteed clean by the guard above.
GIT_SHA=$(git rev-parse --short HEAD)
GIT_MSG=$(git log -1 --pretty=%s)

echo "Deploying $OUT -> Cloudflare Pages ($PROJECT, branch $BRANCH)"
echo ""

# Not exec'd, so the scratch wrangler leaves behind can be swept afterwards.
set +e
"$WRANGLER" pages deploy "$OUT" \
  --project-name="$PROJECT" \
  --branch="$BRANCH" \
  --commit-hash="$GIT_SHA" \
  --commit-message="$GIT_MSG" \
  --commit-dirty="$DIRTY"
STATUS=$?
set -e

# Leave nothing behind: the account cache wrangler just rewrote (the footgun
# this script exists to defuse) and the empty pages-XXXXXX staging directories
# it does not always clean up itself.
rm -f "$PAGES_ACCOUNT_CACHE"
find .wrangler/tmp -maxdepth 1 -type d -name 'pages-*' -empty -delete 2>/dev/null || true

exit $STATUS
