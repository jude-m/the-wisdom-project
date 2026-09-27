#!/bin/bash
# Deploy the app's web build: the databases to R2, then Flutter web to Pages.
#
# Usage:
#   ./scripts/app/web/deploy.sh [--dev]            # test, build, upload
#   ./scripts/app/web/deploy.sh --dev --dry-run    # test, build + check, DON'T upload
#   ./scripts/app/web/deploy.sh --prod             # not set up: exits 3
#
#   --skip-tests       don't run scripts/app/test.sh first
#   --yes              accepted for every deploy.sh's command line; no effect yet
#
# Status: dev=live prod=placeholder
#
# TWO ACCOUNTS IN ONE DEPLOY. The databases go to the R2 bucket in the prod
# (ops) account — R2 is paid, so there is one bucket and every web build reads
# it. The app goes to the dev account's Pages project. Both tokens are checked
# before the tests, so a bad one stops the deploy in seconds.
#
# One R2 file per database version, `<db>-<first 16 hex of its SHA-256>.db.gz`,
# named from the build's own manifest.json — the same name the app asks for.
# A version already in the bucket is not sent again, and a file there is never
# overwritten: a tab on an older build may still be downloading it. So a new
# database costs one upload, and a deploy with the same databases sends none.
# The deploy uploads what is in assets/databases; rebuilding them is
# tools/'s job (npm run generate-bjt / generate-dict).
#
# The build is `flutter build web --release` with RESEARCH_BASE_URL and
# DATABASE_BASE_URL from scripts/config/targets.env, minus the two .db files
# (manifest.json stays: the app reads each version from it). `_headers` comes
# from web/_headers: cross-origin isolation for the databases, noindex on
# every host.
#
# A dry run uploads nothing and needs no credentials, so
# scripts/release_all_dryrun.sh can run it anywhere.
#
# One-time setup (bucket, domain, CORS, tokens, Pages project):
# scripts/app/web/README.md.
# END-USAGE

set -e

. "$(dirname "$0")/../../lib/common.sh"

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
  echo "app web --prod is not set up yet: it will be app.sammaditthi.net in the"
  echo "  ops account. See scripts/app/web/README.md."
  exit 3
fi

PROJECT=$(target APP_WEB_DEV_PROJECT)
BRANCH=$(target APP_WEB_DEV_BRANCH)
BUCKET=$(target DATABASE_BUCKET)
DATABASE_BASE_URL=$(target DATABASE_BASE_URL)
RESEARCH_BASE_URL=$(target RESEARCH_BASE_URL)
ORIGIN="https://$PROJECT.pages.dev"

OUT="build/web"
DB_DIR="$OUT/assets/assets/databases"

# `r2_list BUCKET PREFIX` — the API's listing of BUCKET's objects under PREFIX,
# in the account use_cloudflare selected. The API rather than a request to
# DATABASE_BASE_URL: Cloudflare may cache that 404, and the check after the
# upload would then read it.
r2_list() {
  cf_api "r2/buckets/$1/objects?prefix=$2" && return 0
  echo "error: could not list the R2 bucket '$1' in account" >&2
  echo "       $CLOUDFLARE_ACCOUNT_ID — network down, no such bucket, or the" >&2
  echo "       token lacks 'Workers R2 Storage: Write'." >&2
  return 1
}

cd "$WISDOM_ROOT"

# --- Accounts ---------------------------------------------------------------
# Dev first, for the Pages project; then prod, which stays selected for the
# R2 upload. The bucket is listed here so a token without R2 fails now.
DB_ACCOUNT_LINE="(not checked — dry run)"
APP_ACCOUNT_LINE="(not checked — dry run)"
if [ "$DRY_RUN" = false ]; then
  use_cloudflare dev || exit 1
  APP_ACCOUNT_LINE="$CLOUDFLARE_ACCOUNT_LINE"
  check_pages_branch "$PROJECT" "$BRANCH" || exit 1
  use_cloudflare prod || exit 1
  DB_ACCOUNT_LINE="$CLOUDFLARE_ACCOUNT_LINE"
  r2_list "$BUCKET" "none" >/dev/null || exit 1
  echo ""
fi

# --- Tests ------------------------------------------------------------------
# Without the deploy tokens: no test needs them.
if [ "$SKIP_TESTS" = false ]; then
  if ! env -u CLOUDFLARE_API_TOKEN -u CLOUDFLARE_ACCOUNT_ID ./scripts/app/test.sh; then
    echo "" >&2
    echo "error: scripts/app/test.sh failed (summary above)." >&2
    echo "       Nothing built, nothing uploaded." >&2
    exit 1
  fi
  echo ""
fi

# --- Build ------------------------------------------------------------------
# From empty, so no file of an older build rides along. Without the deploy
# tokens, like the tests.
echo "Building the app for the web (release)..."
rm -rf "$OUT"
env -u CLOUDFLARE_API_TOKEN -u CLOUDFLARE_ACCOUNT_ID flutter build web --release \
  --dart-define=RESEARCH_BASE_URL="$RESEARCH_BASE_URL" \
  --dart-define=DATABASE_BASE_URL="$DATABASE_BASE_URL"
echo ""

if [ ! -f "$OUT/_headers" ]; then
  echo "error: $OUT/_headers is missing — web/_headers should be copied in by" >&2
  echo "       the build. Without it the app can't open its databases." >&2
  exit 1
fi

# --- The databases: checked against the manifest, then moved out ------------
# The manifest in the build is what the app reads, so each .db must be the
# file it describes: a database rebuilt without its manifest (or the reverse)
# would upload under a name the app never asks for.
MANIFEST="$DB_DIR/manifest.json"
if [ ! -f "$MANIFEST" ]; then
  echo "error: $MANIFEST is missing. Build the databases: cd tools && npm run" >&2
  echo "       generate-bjt && npm run generate-dict" >&2
  exit 1
fi
# Kept outside the build so Pages never sees them, and gzipped from here.
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/wisdom-web-dbs.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT

DB_KEYS=()    # <db>-<sha16>.db.gz, the R2 object and the app's URL
DB_FILES=()   # the staged .db
for DB in "$DB_DIR"/*.db; do
  [ -f "$DB" ] || continue
  NAME=$(basename "$DB")
  SHA=$(jq -r --arg n "$NAME" '.[$n].sha256 // empty' "$MANIFEST")
  BYTES=$(jq -r --arg n "$NAME" '.[$n].bytes // empty' "$MANIFEST")
  ACTUAL_SHA=$(shasum -a 256 "$DB" | awk '{print $1}')
  ACTUAL_BYTES=$(wc -c < "$DB" | tr -d ' ')
  if [ "$SHA" != "$ACTUAL_SHA" ] || [ "$BYTES" != "$ACTUAL_BYTES" ]; then
    echo "error: $NAME does not match its manifest.json entry. Rebuild it:" >&2
    echo "       cd tools && npm run generate-${NAME%.db}" >&2
    exit 1
  fi
  mv "$DB" "$STAGE/"
  DB_KEYS+=("${NAME%.db}-${SHA:0:16}.db.gz")
  DB_FILES+=("$STAGE/$NAME")
done
if [ ${#DB_KEYS[@]} -eq 0 ]; then
  echo "error: no databases in $DB_DIR. Build them: cd tools && npm run" >&2
  echo "       generate-bjt && npm run generate-dict" >&2
  exit 1
fi

# Pages refuses any file over 25 MiB.
BIG=$(find "$OUT" -type f -size +25M | head -1)
if [ -n "$BIG" ]; then
  echo "error: $BIG exceeds Cloudflare Pages' 25 MiB per-file limit." >&2
  exit 1
fi

echo "target     $TARGET"
echo "databases  R2 $BUCKET -> $DATABASE_BASE_URL"
echo "           $DB_ACCOUNT_LINE"
for KEY in "${DB_KEYS[@]}"; do
  echo "           $KEY"
done
echo "app        $PROJECT, branch $BRANCH   ($(du -sh "$OUT" | awk '{print $1}'), noindex)"
echo "           $APP_ACCOUNT_LINE"
echo "research   $RESEARCH_BASE_URL"
echo "url        $ORIGIN"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "Dry run: built and checked, NOT uploading."
  exit 0
fi

# --- The databases on R2 (prod account, still selected) ---------------------
# Before the app, so the build never names a file that isn't there yet. Each
# one is checked on every deploy, not only when sent: a file a failed run left
# behind must not pass the next run unchecked.
for i in "${!DB_KEYS[@]}"; do
  KEY="${DB_KEYS[$i]}"
  URL="$DATABASE_BASE_URL/$KEY"
  LISTING=$(r2_list "$BUCKET" "$KEY") || exit 1
  if printf '%s' "$LISTING" | grep -qF "\"key\":\"$KEY\""; then
    echo "$KEY is already on R2."
  else
    echo "Uploading $KEY..."
    gzip -6 -n -c "${DB_FILES[$i]}" > "$STAGE/$KEY"
    "$WRANGLER" r2 object put "$BUCKET/$KEY" --remote \
      --file="$STAGE/$KEY" \
      --content-type=application/octet-stream \
      --content-encoding=gzip \
      --cache-control="public, max-age=31536000, immutable"
    rm -f "$STAGE/$KEY"
  fi

  # Headers only, asked the way the app asks: from its origin, taking gzip.
  # The size the app checks itself, against the manifest.
  echo "Checking $URL..."
  HEADERS=$(curl -sS -I --suppress-connect-headers --max-time 30 \
    -H "Origin: $ORIGIN" -H "Accept-Encoding: gzip" "$URL") || exit 1
  HEADERS=$(printf '%s' "$HEADERS" | tr -d '\r')
  STATUS_LINE=$(printf '%s' "$HEADERS" | head -1)
  PROBLEM=""
  case "$STATUS_LINE" in
    HTTP/*" 200"*) ;;
    *) PROBLEM="it answers '$STATUS_LINE', not 200" ;;
  esac
  if [ -z "$PROBLEM" ] && ! printf '%s' "$HEADERS" \
      | grep -qiE "^access-control-allow-origin: *(\*|$ORIGIN)$"; then
    PROBLEM="it has no CORS header for $ORIGIN (the bucket's CORS rule)"
  fi
  if [ -z "$PROBLEM" ] && ! printf '%s' "$HEADERS" \
      | grep -qi '^content-encoding: *gzip$'; then
    PROBLEM="it is not served with Content-Encoding: gzip"
  fi
  if [ -n "$PROBLEM" ]; then
    echo "error: $URL: $PROBLEM." >&2
    echo "       The app was not deployed. Fix it, purge that URL from" >&2
    echo "       Cloudflare's cache (scripts/app/web/README.md, Rollback)," >&2
    echo "       then deploy again." >&2
    exit 1
  fi
done
echo ""

# --- Deploy the app (dev account) -------------------------------------------
use_cloudflare dev || exit 1
echo ""

git_stamp

echo "Deploying $OUT -> Cloudflare Pages ($PROJECT, branch $BRANCH)"
echo ""
set +e
"$WRANGLER" pages deploy "$OUT" \
  --project-name="$PROJECT" \
  --branch="$BRANCH" \
  --commit-hash="$GIT_SHA" \
  --commit-message="$GIT_MSG" \
  --commit-dirty="$GIT_DIRTY"
STATUS=$?
set -e
find .wrangler/tmp -maxdepth 1 -type d -name 'pages-*' -empty -delete 2>/dev/null || true
[ $STATUS -eq 0 ] || exit $STATUS

# --- After the upload: the app answers, isolated and noindex ----------------
echo ""
echo "Checking $ORIGIN/..."
if ! expect_http "$ORIGIN/"; then
  echo "       Uploaded; to go back, see Rollback in scripts/app/web/README.md." >&2
  exit 1
fi
RESPONSE_HEADERS=$(printf '%s' "$HTTP_RESPONSE" | tr -d '\r' | sed '/^$/q')
for WANT in 'x-robots-tag:.*noindex' \
            'cross-origin-opener-policy: *same-origin' \
            'cross-origin-embedder-policy: *require-corp'; do
  if ! printf '%s' "$RESPONSE_HEADERS" | grep -qi "^$WANT"; then
    echo "error: uploaded, but $ORIGIN/ answers without '$WANT' (web/_headers)." >&2
    exit 1
  fi
done
echo "OK: $ORIGIN/ answers 200, isolated and noindex."
