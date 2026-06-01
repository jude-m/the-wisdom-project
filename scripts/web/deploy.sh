#!/bin/bash
# =============================================================================
#  The Wisdom Project — end-to-end deploy to the Windows server.
#
#  Runs analyze → unit tests → build → strip → integration tests → rsync →
#  poll /healthz until the new SHA is live.
#
#  Usage:
#    ./scripts/web/deploy.sh                # full pipeline
#    ./scripts/web/deploy.sh --skip-tests   # skip unit + integration tests
#    ./scripts/web/deploy.sh --dry-run      # run tests + build, skip rsync
#    ./scripts/web/deploy.sh -h             # help
#
#  Auto-mounts the SMB share //192.168.1.200/wisdom-project at
#  /Volumes/wisdom-project if not already mounted. Requires the password
#  to be saved in Keychain (tick "Remember this password" on first Finder
#  mount: Go → Connect to Server → smb://192.168.1.200/wisdom-project).
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------- Config
readonly WINDOWS_IP="192.168.1.200"
readonly WINDOWS_SSH_USER="admin"
readonly SERVER_PORT="8081"
readonly SHARE_MOUNT="/Volumes/wisdom-project"
readonly HEALTHZ_URL="http://${WINDOWS_IP}:${SERVER_PORT}/healthz"
readonly HEALTH_POLL_TIMEOUT_S=120

# ---------------------------------------------------------------- Args
SKIP_TESTS=false
DRY_RUN=false

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-tests) SKIP_TESTS=true; shift ;;
    --dry-run)    DRY_RUN=true;    shift ;;
    -h|--help)    usage ;;
    *) echo "Unknown option: $1" >&2; echo "Run with -h for help." >&2; exit 1 ;;
  esac
done

# ---------------------------------------------------------------- Output helpers
if [[ -t 1 ]]; then
  BOLD=$(tput bold 2>/dev/null || echo)
  RED=$(tput setaf 1 2>/dev/null || echo)
  GREEN=$(tput setaf 2 2>/dev/null || echo)
  YELLOW=$(tput setaf 3 2>/dev/null || echo)
  BLUE=$(tput setaf 4 2>/dev/null || echo)
  RESET=$(tput sgr0 2>/dev/null || echo)
else
  BOLD=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi

phase() { printf '\n%s==> %s%s\n' "${BOLD}${BLUE}" "$1" "${RESET}"; }
ok()    { printf '%s✓%s %s\n' "${GREEN}" "${RESET}" "$1"; }
warn()  { printf '%s!%s %s\n' "${YELLOW}" "${RESET}" "$1"; }
err()   { printf '%s✗%s %s\n' "${RED}" "${RESET}" "$1" >&2; }
die()   { err "$1"; exit 1; }

# ---------------------------------------------------------------- Setup
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

# ---------------------------------------------------------------- Preflight
phase "Preflight"

# Try to auto-mount the SMB share if it isn't already. `open smb://…`
# delegates to Finder, which pulls saved credentials from Keychain (no
# password prompt if "Remember this password" was ticked on first mount).
# Poll for up to ~15s for the mount point to appear.
mount_share() {
  local url="smb://${WINDOWS_IP}/wisdom-project"
  warn "Share not mounted — attempting auto-mount via $url"
  open "$url" >/dev/null 2>&1 || true
  local waited=0
  while (( waited < 15 )); do
    [[ -d "$SHARE_MOUNT" ]] && return 0
    sleep 1
    waited=$((waited + 1))
  done
  return 1
}

if [[ ! -d "$SHARE_MOUNT" ]]; then
  mount_share || die "Auto-mount failed. Mount manually once in Finder (Go → Connect to Server → smb://${WINDOWS_IP}/wisdom-project) and tick 'Remember this password in my keychain'."
fi

touch "$SHARE_MOUNT/.write-test" 2>/dev/null || die "Share not writable"
rm -f "$SHARE_MOUNT/.write-test"
ok "Share mounted and writable"

GIT_SHA=$(git rev-parse --short HEAD)
GIT_DIRTY=""
git diff --quiet 2>/dev/null || GIT_DIRTY=" (dirty tree)"
BUILT_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
ok "Deploying $GIT_SHA${GIT_DIRTY} (built $BUILT_AT)"
[[ "$DRY_RUN" == true ]] && warn "DRY-RUN mode — will stop before rsync"

# ---------------------------------------------------------------- Phase 1: analyze
phase "Phase 1/7: flutter analyze (app)"
flutter analyze || die "app analyze failed"
ok "app analyze green"

# Pure-Dart packages (wisdom_shared, server) ship to the server too, but
# `flutter analyze` only covers the app package. Analyze each shipped Dart
# package with `dart analyze` so their lib code is linted as well. pub get
# first so imports resolve (idempotent when deps are already fetched).
for pkg in packages/wisdom_shared server; do
  phase "Phase 1/7: dart analyze ($pkg)"
  ( cd "$pkg" && dart pub get >/dev/null && dart analyze ) || die "$pkg analyze failed"
  ok "$pkg analyze green"
done

# ---------------------------------------------------------------- Phase 2: unit tests
if [[ "$SKIP_TESTS" == true ]]; then
  phase "Phase 2/7: unit tests — SKIPPED (--skip-tests)"
else
  phase "Phase 2/7: flutter test (app)"
  flutter test || die "app unit tests failed"
  ok "app unit tests green"

  # Pure-Dart packages (wisdom_shared, server) are rsynced to the server below,
  # but `flutter test` only runs the app package — each package is its own test
  # target. Run their `dart test` suites here so shared logic can't regress
  # unnoticed. A package with no tests yet (e.g. server today) is skipped.
  for pkg in packages/wisdom_shared server; do
    if [[ -n "$(find "$pkg/test" -name '*_test.dart' -print -quit 2>/dev/null)" ]]; then
      phase "Phase 2/7: dart test ($pkg)"
      ( cd "$pkg" && dart pub get >/dev/null && dart test ) \
        || die "$pkg tests failed"
      ok "$pkg tests green"
    else
      warn "Phase 2/7: dart test ($pkg) — no tests found, skipping"
    fi
  done
fi

# ---------------------------------------------------------------- Phase 3: build
phase "Phase 3/7: flutter build web --release"
# --dart-define values are baked into the compiled JS as compile-time
# constants (read via String.fromEnvironment in lib/core/version/build_info.dart).
# BUILD_SHA lets the running client compare itself against the deployed
# sha from /healthz; VERSION_CHECK_ENABLED is a kill switch for the
# update banner (set to false here once dev phase is over).
# VERSION_CHECK_POLL_SECONDS controls how often the running client polls
# /healthz — drop to 60 during rapid-dev days, raise to 300 (or delete
# the line, since 300 is the default) once releases slow down.
flutter build web --release \
  --dart-define=BUILD_SHA="$GIT_SHA" \
  --dart-define=VERSION_CHECK_ENABLED=true \
  --dart-define=VERSION_CHECK_POLL_SECONDS=120 \
  || die "web build failed"

# Strip server-only assets from the web bundle (served by API instead).
[[ -d build/web/assets/assets/databases ]] && rm -rf build/web/assets/assets/databases
[[ -d build/web/assets/assets/text      ]] && rm -rf build/web/assets/assets/text

# Strip the Flutter service worker. Without it, redeploys serve fresh
# code immediately instead of stale cache until the user hard-reloads.
[[ -f build/web/flutter_service_worker.js ]] && rm -f build/web/flutter_service_worker.js

BUILD_SIZE=$(du -sh build/web | awk '{print $1}')
ok "build complete ($BUILD_SIZE)"

# ---------------------------------------------------------------- Phase 4: integration tests
if [[ "$SKIP_TESTS" == true ]]; then
  phase "Phase 4/7: integration tests — SKIPPED (--skip-tests)"
else
  phase "Phase 4/7: integration tests on macOS (~8 min)"
  flutter test integration_test/all_tests.dart -d macos || die "integration tests failed"
  ok "integration tests green"
fi

# ---------------------------------------------------------------- Phase 5: rsync
if [[ "$DRY_RUN" == true ]]; then
  phase "Dry-run — stopping before rsync"
  exit 0
fi

phase "Phase 5/7: rsync to $SHARE_MOUNT"

# server/ — --exclude protects target's sqlite3.dll/def/.dart_tool/log from
# --delete, since excluded files are skipped for both transfer AND deletion.
rsync -rt --modify-window=2 --delete \
  --exclude '.dart_tool' \
  --exclude 'server.log' \
  --exclude '.DS_Store' \
  --exclude 'sqlite3.dll' \
  --exclude 'sqlite3.def' \
  server/ "$SHARE_MOUNT/server/"

rsync -rt --modify-window=2 --delete \
  --exclude '.dart_tool' \
  --exclude '.DS_Store' \
  packages/wisdom_shared/ "$SHARE_MOUNT/packages/wisdom_shared/"

rsync -rt --modify-window=2 --delete \
  --exclude '.DS_Store' \
  build/web/ "$SHARE_MOUNT/build/web/"

# assets/ — rsync is incremental; unchanged files transfer in ms.
# Exclude SQLite runtime files (.db-shm, .db-wal, .db-journal) — they are
# created by the engine when a .db is opened in WAL mode, and get locked
# by the running Windows server, causing "Resource busy" errors on rsync.
# The server recreates them fresh on startup.
rsync -rt --modify-window=2 --delete \
  --exclude '.DS_Store' \
  --exclude '*.db-shm' \
  --exclude '*.db-wal' \
  --exclude '*.db-journal' \
  assets/ "$SHARE_MOUNT/assets/"

# Windows helper scripts at the deploy root.
cp scripts/web/run_win.bat     "$SHARE_MOUNT/run_win.bat"
cp scripts/web/restart_win.bat "$SHARE_MOUNT/restart_win.bat"

ok "rsync complete"

# ---------------------------------------------------------------- Phase 6: DEPLOY.json
phase "Phase 6/7: write DEPLOY.json"

# Build a JSON array from RELEASE_NOTES.md.
# Only lines under the `## Current release` heading are read — anything
# above it is treated as documentation. Of those lines:
#   - blank lines are skipped
#   - HTML comment delimiters and lines inside <!-- ... --> are skipped
#   - a leading `- `, `* ` or `1. ` bullet marker is stripped
#   - everything else becomes one banner bullet
# All bash; avoids requiring jq/python on the deploy machine.
build_notes_json() {
  local file="$PROJECT_ROOT/RELEASE_NOTES.md"
  if [[ ! -f "$file" ]]; then
    # Surface a warning to stderr so a forgotten file doesn't silently
    # ship an empty banner. Don't fail the deploy — an empty notes list
    # is the documented "show a generic banner" fallback.
    warn "RELEASE_NOTES.md not found — banner will fall back to a generic message"
    printf '[]'
    return
  fi
  local first=true line in_release=false in_comment=false
  printf '['
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Trim leading and trailing whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    # Track when we enter the "Current release" section. Stop at the next H2.
    if [[ "$line" == "## Current release" ]]; then
      in_release=true
      continue
    fi
    if [[ "$in_release" == true && "$line" == "## "* ]]; then
      break
    fi
    [[ "$in_release" == true ]] || continue
    # Skip HTML comment blocks (in case someone tucks notes inline)
    if [[ "$line" == "<!--"* ]]; then in_comment=true; fi
    if [[ "$in_comment" == true ]]; then
      [[ "$line" == *"-->" ]] && in_comment=false
      continue
    fi
    [[ -z "$line" ]] && continue
    # Strip a single leading bullet marker
    if [[ "$line" =~ ^(-[[:space:]]+|\*[[:space:]]+|[0-9]+\.[[:space:]]+) ]]; then
      line="${line#"${BASH_REMATCH[0]}"}"
    fi
    # Normalise tabs to spaces — raw control chars are illegal inside
    # a JSON string literal. (The line-by-line read already excludes
    # embedded newlines.)
    line="${line//$'\t'/ }"
    # JSON-escape backslash and double-quote
    line="${line//\\/\\\\}"
    line="${line//\"/\\\"}"
    if [[ "$first" == true ]]; then
      printf '"%s"' "$line"
      first=false
    else
      printf ',"%s"' "$line"
    fi
  done < "$file"
  printf ']'
}
NOTES_JSON=$(build_notes_json)
# count = (number of '","' separators) + 1, or 0 when the array is empty.
# `|| true` keeps `set -o pipefail` happy when grep finds nothing.
if [[ "$NOTES_JSON" == "[]" ]]; then
  NOTES_COUNT=0
else
  SEPARATORS=$(printf '%s' "$NOTES_JSON" | grep -oE '","' | wc -l | tr -d ' ' || true)
  NOTES_COUNT=$((SEPARATORS + 1))
fi

# Write to a .tmp sibling then rename into place. rename is atomic on
# the same filesystem (and single-op on SMB), so a mid-write share hiccup
# leaves DEPLOY.json untouched instead of half-written.
cat > "$SHARE_MOUNT/DEPLOY.json.tmp" <<EOF
{
  "sha": "$GIT_SHA",
  "builtAt": "$BUILT_AT",
  "notes": $NOTES_JSON
}
EOF
mv "$SHARE_MOUNT/DEPLOY.json.tmp" "$SHARE_MOUNT/DEPLOY.json"
ok "DEPLOY.json: sha=$GIT_SHA builtAt=$BUILT_AT notes=$NOTES_COUNT"

# ---------------------------------------------------------------- Phase 7: restart + verify
phase "Phase 7/7: restart Windows server + verify"

# Trigger restart over SSH. BatchMode=yes refuses interactive password
# prompts (keeps the script from hanging if key auth is broken),
# ConnectTimeout=5 keeps it responsive if the box is offline.
SSH_TARGET="${WINDOWS_SSH_USER}@${WINDOWS_IP}"
if ssh -o BatchMode=yes -o ConnectTimeout=5 "$SSH_TARGET" \
       'C:\wisdom-project\restart_win.bat'; then
  ok "Restart triggered via SSH"
else
  warn "SSH restart failed — fall back to manual restart on Windows:"
  cat <<EOF

  Fast:    double-click C:\\wisdom-project\\restart_win.bat
  Manual:  Ctrl+C the cmd window running run_win.bat → press Y → rerun run_win.bat

EOF
fi

echo
echo "Waiting for /healthz to report sha=${GIT_SHA}..."
echo

ELAPSED=0
while [[ $ELAPSED -lt $HEALTH_POLL_TIMEOUT_S ]]; do
  RESPONSE=$(curl -fsm 3 "$HEALTHZ_URL" 2>/dev/null || true)
  # Robust sha extraction: failures inside this pipeline must NOT crash
  # the script (e.g. old server returning HTML, or no sha field yet).
  # Running under `set -euo pipefail`, so we unset pipefail just here.
  LIVE_SHA=""
  if [[ -n "$RESPONSE" ]]; then
    set +o pipefail
    LIVE_SHA=$(printf '%s' "$RESPONSE" | grep -oE '"sha":"[^"]*"' 2>/dev/null | head -1 | cut -d'"' -f4 || true)
    set -o pipefail
  fi
  if [[ "$LIVE_SHA" == "$GIT_SHA" ]]; then
    ok "Server healthy — deploy complete (sha=$GIT_SHA)"
    exit 0
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
done

warn "Server did not report sha=$GIT_SHA within ${HEALTH_POLL_TIMEOUT_S}s."
warn "Files are synced — just the restart didn't confirm in time."
warn "Check: curl $HEALTHZ_URL"
exit 2
