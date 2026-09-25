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
_STEP_FAILED=0
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
    _STEP_FAILED=1
  fi
}

# `step_summary TITLE` — the table of every run_step so far; returns 1 if any
# failed, so a test.sh can end with `step_summary "…"; exit $?`.
step_summary() {
  local line
  echo ""
  echo "${BOLD}── $1${NC}"
  for line in "${_STEP_LINES[@]}"; do
    echo "$line"
  done
  return $_STEP_FAILED
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
