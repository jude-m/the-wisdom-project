# Shared helpers for the scripts under scripts/. Sourced, never run:
#   . "$(dirname "$0")/../lib/common.sh"
# Source it before the script's own `cd`; it finds the repo from its own path.

WISDOM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGETS_FILE="$WISDOM_ROOT/scripts/config/targets.env"
SECRETS_FILE="$WISDOM_ROOT/scripts/config/secrets.env"

_check_name() {
  case "$1" in
    ''|[0-9]*|*[!A-Za-z0-9_]*) echo "error: bad key name '$1'." >&2; return 1 ;;
  esac
}

# Prints one key of a sourced file, from a subshell so nothing else in the file
# reaches the caller. stdout is dropped while sourcing so a stray echo can't
# become part of the value.
_read_key() {
  local file="$1" name="$2"
  _check_name "$name" || return 1
  [ -f "$file" ] || return 0
  (
    unset "$name"
    # shellcheck source=/dev/null
    . "$file" >/dev/null
    printf '%s' "${!name-}"
  )
}

# `target NAME` — a key from targets.env, never from the environment, so a
# deploy goes where the file says. Fails on an empty key.
target() {
  local value
  if [ ! -f "$TARGETS_FILE" ]; then
    echo "error: scripts/config/targets.env is missing." >&2
    return 1
  fi
  value=$(_read_key "$TARGETS_FILE" "$1") || return 1
  if [ -z "$value" ]; then
    echo "error: $1 is empty in scripts/config/targets.env." >&2
    return 1
  fi
  printf '%s' "$value"
}

# `secret NAME` — the environment when set (CI), else secrets.env. Prints
# nothing when neither has it; the caller decides whether that is an error.
secret() {
  _check_name "$1" || return 1
  if [ -n "${!1-}" ]; then
    printf '%s' "${!1}"
    return 0
  fi
  _read_key "$SECRETS_FILE" "$1"
}

# `write_worker_secrets FILE WORKER_NAME=SECRET_NAME ...` — a dotenv file for
# wrangler holding only the pairs whose secret is set. An empty one is left out
# rather than written empty: a key left out stays on the Worker as it is.
write_worker_secrets() {
  local out="$1" pair value
  shift
  : > "$out"
  for pair in "$@"; do
    value=$(secret "${pair#*=}") || return 1
    [ -n "$value" ] || continue
    case "$value" in
      *"'"*|*$'\n'*)
        echo "error: ${pair#*=} holds a quote or a newline; wrangler's file can't carry it." >&2
        return 1 ;;
    esac
    printf "%s='%s'\n" "${pair%%=*}" "$value" >> "$out"
  done
}

# `usage` — prints the calling script's header, line 2 down to `# END-USAGE`.
usage() {
  sed -n '2,/^# END-USAGE$/p' "$0" | sed 's/^# \{0,1\}//; /^END-USAGE$/d'
  exit 0
}

# Colours only on a terminal, so a CI log or a pipe gets plain text.
if [ -t 1 ]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; BOLD=$'\033[1m'; NC=$'\033[0m'
else
  RED=""; GREEN=""; BOLD=""; NC=""
fi

# `run_step NAME COMMAND...` — runs one step of a test.sh in a subshell (a `cd`
# inside stays inside), records PASS/FAIL and its time, and never exits, so one
# red step still lets the rest run — under `set -e` too, since the step runs as
# an `if` condition. That also turns `set -e` off inside the step, so a step's
# status is its last command's: chain its commands with `&&`. `step_summary`
# prints them all.
_STEP_LINES=()
_STEP_FAILS=0
run_step() {
  local name="$1" start status
  shift
  echo ""
  echo "${BOLD}── $name${NC}"
  start=$SECONDS
  if ( "$@" ); then status=0; else status=$?; fi
  if [ $status -eq 0 ]; then
    _STEP_LINES+=("$(printf '%-28s %sPASS%s  %4ss' "$name" "$GREEN" "$NC" $((SECONDS - start)))")
  else
    _STEP_LINES+=("$(printf '%-28s %sFAIL%s  %4ss' "$name" "$RED" "$NC" $((SECONDS - start)))")
    _STEP_FAILS=$((_STEP_FAILS + 1))
  fi
}

# `step_summary TITLE` — the table of every run_step so far, then a one-line
# verdict as the last thing printed; returns 1 if any failed, so a test.sh can
# end with it.
step_summary() {
  local line total=${#_STEP_LINES[@]}
  echo ""
  echo "${BOLD}── $1${NC}"
  for line in "${_STEP_LINES[@]}"; do
    echo "$line"
  done
  echo ""
  if [ $_STEP_FAILS -eq 0 ]; then
    echo "${GREEN}${BOLD}$1: $total of $total steps passed.${NC}"
    return 0
  fi
  echo "${RED}${BOLD}$1: $_STEP_FAILS of $total steps FAILED.${NC}"
  return 1
}

# wrangler 4.112 requires Node >= 22 (its package.json `engines`); the system
# default may be older, so fall back to the newest nvm-installed Node and then
# re-check, because the newest installed one may still be too old.
require_node22() {
  local major nvm_bin
  major=$(node -v 2>/dev/null | sed 's/^v\([0-9]*\).*/\1/')
  if [ "${major:-0}" -lt 22 ]; then
    nvm_bin=$(ls -d "$HOME/.nvm/versions/node"/v*/bin 2>/dev/null | sort -V | tail -1)
    [ -n "$nvm_bin" ] && export PATH="$nvm_bin:$PATH"
    major=$(node -v 2>/dev/null | sed 's/^v\([0-9]*\).*/\1/')
    if [ "${major:-0}" -lt 22 ]; then
      echo "error: wrangler needs Node >= 22 (found ${major:-none})." >&2
      echo "       Install one, e.g. \`nvm install 22\`." >&2
      exit 1
    fi
  fi
}

# wrangler from research_server's lockfile, the repo's only copy, so every
# Cloudflare deploy runs one version. Never `npx wrangler`: with no local copy
# it downloads whatever is newest. Call require_node22 first.
WRANGLER="$WISDOM_ROOT/research_server/node_modules/.bin/wrangler"
research_deps() {
  [ -d "$WISDOM_ROOT/research_server/node_modules" ] && return 0
  echo "Installing research_server dependencies (npm ci)..."
  (cd "$WISDOM_ROOT/research_server" && npm ci)
}

# `use_cloudflare dev|prod` — points wrangler at that target's account: maps
# CLOUDFLARE_<DEV|PROD>_API_TOKEN/_ACCOUNT_ID to wrangler's own names, then asks
# `wrangler whoami` and fails unless the token reaches that account. Both
# accounts work this way; there is no `wrangler login` path. Sets
# CLOUDFLARE_ACCOUNT_LINE for the deploy banner.
use_cloudflare() {
  local upper token account json ids name
  case "$1" in
    dev|prod) upper=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]') ;;
    *) echo "error: use_cloudflare takes dev or prod, not '$1'." >&2; return 1 ;;
  esac
  require_node22
  research_deps || return 1
  token=$(secret "CLOUDFLARE_${upper}_API_TOKEN") || return 1
  account=$(secret "CLOUDFLARE_${upper}_ACCOUNT_ID") || return 1
  if [ -z "$token" ] || [ -z "$account" ]; then
    echo "error: CLOUDFLARE_${upper}_API_TOKEN and CLOUDFLARE_${upper}_ACCOUNT_ID must" >&2
    echo "       both be set (environment or scripts/config/secrets.env)." >&2
    return 1
  fi
  export CLOUDFLARE_API_TOKEN="$token" CLOUDFLARE_ACCOUNT_ID="$account"
  # wrangler prefers a global key + email over the token, so a pair left in the
  # shell would deploy as someone else.
  unset CLOUDFLARE_API_KEY CLOUDFLARE_EMAIL

  # --json, not the human table: its box characters pick up ANSI colour and the
  # name then parses out empty.
  echo "Checking Cloudflare account ($1)..."
  json=$("$WRANGLER" whoami --json 2>/dev/null || true)
  ids=$(printf '%s' "$json" | grep -oE '"id" *: *"[0-9a-f]{32}"' \
    | grep -oE '[0-9a-f]{32}' | sort -u | tr '\n' ' ' || true)
  name=$(printf '%s' "$json" | grep -oE '"name" *: *"[^"]*"' | head -1 \
    | sed -E 's/.*: *"//; s/"$//' || true)
  if [ -z "$ids" ]; then
    echo "error: could not verify the Cloudflare account — \`wrangler whoami\`" >&2
    echo "       returned nothing. Likely CLOUDFLARE_${upper}_API_TOKEN is expired," >&2
    echo "       is missing 'Account Settings: Read', or there is no network." >&2
    return 1
  fi
  case " $ids " in
    *" $account "*) ;;
    *)
      echo "error: the token reaches account(s) [$ids]," >&2
      echo "       but CLOUDFLARE_${upper}_ACCOUNT_ID names $account." >&2
      return 1 ;;
  esac
  CLOUDFLARE_ACCOUNT_LINE="${name:-unknown}   ($account)"
}

# `cf_api PATH` — GETs PATH under the selected account's Cloudflare API and
# prints the reply without spaces or newlines; fails unless it reports success.
# The token goes to curl on stdin, so it never shows in the process list.
cf_api() {
  local json
  json=$(printf 'Authorization: Bearer %s\n' "$CLOUDFLARE_API_TOKEN" \
    | curl -sS --max-time 15 -H @- \
    "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/$1" \
    2>/dev/null | tr -d ' \n' || true)
  case "$json" in
    *'"success":true'*) printf '%s' "$json" ;;
    *) return 1 ;;
  esac
}

# `check_pages_branch PROJECT BRANCH` — fails unless the Pages project exists
# in the account use_cloudflare selected and BRANCH is its production branch.
# A deploy to any other branch is a preview at <branch>.<project>.pages.dev, so
# the check after the upload would read the old deployment and pass; and
# `pages deploy` offers to create a missing project.
check_pages_branch() {
  local json production
  echo "Checking $2 is the production branch of $1..."
  if ! json=$(cf_api "pages/projects/$1"); then
    echo "error: could not read the Pages project '$1' in account" >&2
    echo "       $CLOUDFLARE_ACCOUNT_ID — network down, or the project does not" >&2
    echo "       exist there (see the product's README). Nothing uploaded." >&2
    return 1
  fi
  production=$(printf '%s' "$json" \
    | sed -n 's/.*"production_branch":"\([^"]*\)".*/\1/p')
  if [ "$production" != "$2" ]; then
    echo "error: $1's production branch is '${production:-unreadable}'," >&2
    echo "       but targets.env deploys to '$2'. Make them agree. Nothing uploaded." >&2
    return 1
  fi
}

# `expect_http URL` — GETs URL until it answers 200, a few tries apart (a fresh
# deploy can take a moment to arrive). Leaves headers + body in HTTP_RESPONSE.
# --suppress-connect-headers: behind a proxy, `curl -i` otherwise prints the
# proxy's own "200 Connection Established" before the site's reply.
expect_http() {
  local try
  for try in 1 2 3 4 5 6; do
    HTTP_RESPONSE=$(curl -sS -i --suppress-connect-headers --max-time 15 "$1" \
      2>/dev/null || true)
    case "$(printf '%s' "$HTTP_RESPONSE" | head -1)" in
      HTTP/*" 200"*) return 0 ;;
    esac
    [ $try -lt 6 ] && sleep 5
  done
  echo "error: $1 did not answer 200." >&2
  return 1
}

# `require_release_commit BRANCH` — fails unless HEAD is BRANCH and the tree is
# clean, so a release can be rebuilt from its commit. `git status --porcelain`
# rather than `git diff`, so staged and untracked files count too: a
# never-added file is invisible to `git diff` yet part of the build.
require_release_commit() {
  local branch
  branch=$(git -C "$WISDOM_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
  if [ "$branch" != "$1" ]; then
    echo "error: a release must be cut from '$1' (on '$branch')." >&2
    echo "       Merge first, then release." >&2
    return 1
  fi
  if [ -n "$(git -C "$WISDOM_ROOT" status --porcelain 2>/dev/null)" ]; then
    echo "error: working tree is dirty — a release must be reproducible from a commit." >&2
    git -C "$WISDOM_ROOT" status --short >&2
    return 1
  fi
}

# `confirm_release QUESTION` — asks QUESTION [y/N] and exits unless the answer
# is yes. Needs a terminal; automation passes --yes instead of calling this.
confirm_release() {
  local reply
  if [ ! -t 0 ]; then
    echo "error: a release needs a terminal to confirm. Pass --yes in automation." >&2
    exit 1
  fi
  read -r -p "$1 [y/N] " reply
  case "$reply" in
    y|Y|yes|YES) echo "" ;;
    *) echo "Aborted."; exit 1 ;;
  esac
}

# `git_stamp` — sets GIT_SHA (short) and GIT_MSG (subject) of HEAD, and
# GIT_DIRTY (true/false: uncommitted work), to tag a deployment with the
# commit it came from.
git_stamp() {
  GIT_SHA=$(git -C "$WISDOM_ROOT" rev-parse --short HEAD)
  GIT_MSG=$(git -C "$WISDOM_ROOT" log -1 --pretty=%s)
  if [ -z "$(git -C "$WISDOM_ROOT" status --porcelain 2>/dev/null)" ]; then
    GIT_DIRTY=false
  else
    GIT_DIRTY=true
  fi
}

# `research_var NAME` — one var from research_server/wrangler.jsonc. TypeScript's
# parser, because the file has comments and URLs, so stripping `//` with sed
# would cut the URLs too. Call research_deps first.
research_var() {
  if ! (cd "$WISDOM_ROOT/research_server" && node -e '
    const ts = require("typescript");
    const text = require("fs").readFileSync("wrangler.jsonc", "utf8");
    const { config, error } = ts.parseConfigFileTextToJson("wrangler.jsonc", text);
    if (error || !config || !config.vars) process.exit(1);
    process.stdout.write(String(config.vars[process.argv[1]] ?? ""));
  ' "$1"); then
    echo "error: can't read $1 from research_server/wrangler.jsonc." >&2
    return 1
  fi
}

# `check_research_store` — fails unless RESEARCH_GEMINI_API_KEY can open
# RESEARCH_STORE. A store belongs to the Google project that made it, and so
# does a key, so the two switch together or research breaks. One metadata
# lookup, no generation. With no key it only warns: the Worker keeps the key it
# has, which no script can read.
check_research_store() {
  local key store resp code message
  store=$(research_var RESEARCH_STORE) || return 1
  if [ -z "$store" ]; then
    echo "error: RESEARCH_STORE is empty in research_server/wrangler.jsonc." >&2
    return 1
  fi
  key=$(secret RESEARCH_GEMINI_API_KEY) || return 1
  if [ -z "$key" ]; then
    echo "warning: no RESEARCH_GEMINI_API_KEY, so $store is not checked." >&2
    echo "         The key already on the Worker must be able to open it." >&2
    return 0
  fi
  echo "Checking RESEARCH_GEMINI_API_KEY can open $store..."
  # The key goes in on stdin (-H @-), so it never shows in the process list.
  resp=$(printf 'x-goog-api-key: %s\n' "$key" | curl -sS --max-time 15 -H @- \
    -w '\n%{http_code}' "https://generativelanguage.googleapis.com/v1beta/$store" \
    2>/dev/null) || true
  code=${resp##*$'\n'}
  [ "$code" = 200 ] && return 0
  if [ "$code" = 000 ] || [ -z "$code" ]; then
    echo "error: could not reach Google to check $store (network?)." >&2
    return 1
  fi
  message=$(printf '%s' "$resp" | sed -n 's/.*"message": *"\([^"]*\)".*/\1/p' | head -1)
  echo "error: RESEARCH_GEMINI_API_KEY cannot open $store" >&2
  echo "       (HTTP $code${message:+: $message})." >&2
  # 403/404 is "this key can't see that store". A 400 is the key itself, or
  # Google's location block, where a project hint would mislead.
  case "$code" in
    403|404) echo "       The key and RESEARCH_STORE must come from the same Google project." >&2 ;;
  esac
  return 1
}

# `free_port PORT` — stops whatever listens on PORT, so a re-run doesn't hit
# "address already in use". Waits until the port is really free, escalating to
# SIGKILL; a fixed sleep is racy. -sTCP:LISTEN so a browser tab or app holding
# a keep-alive connection to the port is not a target.
free_port() {
  local pids
  pids=$(lsof -ti:"$1" -sTCP:LISTEN 2>/dev/null || true)
  [ -n "$pids" ] || return 0
  echo "Stopping process on port $1 (PID: $pids)..."
  echo "$pids" | xargs kill 2>/dev/null || true
  for _ in $(seq 1 10); do
    sleep 0.5
    pids=$(lsof -ti:"$1" -sTCP:LISTEN 2>/dev/null || true)
    [ -z "$pids" ] && break
    echo "$pids" | xargs kill -9 2>/dev/null || true
  done
}
