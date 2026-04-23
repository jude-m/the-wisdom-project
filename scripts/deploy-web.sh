#!/bin/bash
# =============================================================================
#  The Wisdom Project — end-to-end deploy to the Windows server.
#
#  Runs analyze → unit tests → build → strip → integration tests → rsync →
#  poll /healthz until the new SHA is live.
#
#  Usage:
#    ./scripts/deploy-web.sh                # full pipeline
#    ./scripts/deploy-web.sh --skip-tests   # skip unit + integration tests
#    ./scripts/deploy-web.sh --dry-run      # run tests + build, skip rsync
#    ./scripts/deploy-web.sh -h             # help
#
#  Assumes the SMB share //192.168.1.200/wisdom-project is mounted at
#  /Volumes/wisdom-project (Finder: Go → Connect to Server).
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------- Config
readonly WINDOWS_IP="192.168.1.200"
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
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# ---------------------------------------------------------------- Preflight
phase "Preflight"
[[ -d "$SHARE_MOUNT" ]] || die "Share not mounted at $SHARE_MOUNT. Finder → Go → Connect to Server → smb://${WINDOWS_IP}/wisdom-project"
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
phase "Phase 1/7: flutter analyze"
flutter analyze || die "analyze failed"
ok "analyze green"

# ---------------------------------------------------------------- Phase 2: unit tests
if [[ "$SKIP_TESTS" == true ]]; then
  phase "Phase 2/7: unit tests — SKIPPED (--skip-tests)"
else
  phase "Phase 2/7: flutter test"
  flutter test || die "unit tests failed"
  ok "unit tests green"
fi

# ---------------------------------------------------------------- Phase 3: build
phase "Phase 3/7: flutter build web --release"
flutter build web --release || die "web build failed"

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
cp scripts/windows/serve-web.bat "$SHARE_MOUNT/serve-web.bat"
cp scripts/windows/restart.bat   "$SHARE_MOUNT/restart.bat"

ok "rsync complete"

# ---------------------------------------------------------------- Phase 6: DEPLOY.json
phase "Phase 6/7: write DEPLOY.json"
# Write to a .tmp sibling then rename into place. rename is atomic on
# the same filesystem (and single-op on SMB), so a mid-write share hiccup
# leaves DEPLOY.json untouched instead of half-written.
cat > "$SHARE_MOUNT/DEPLOY.json.tmp" <<EOF
{
  "sha": "$GIT_SHA",
  "builtAt": "$BUILT_AT"
}
EOF
mv "$SHARE_MOUNT/DEPLOY.json.tmp" "$SHARE_MOUNT/DEPLOY.json"
ok "DEPLOY.json: sha=$GIT_SHA builtAt=$BUILT_AT"

# ---------------------------------------------------------------- Phase 7: restart + verify
phase "Phase 7/7: restart Windows server + verify"

cat <<EOF

${BOLD}${YELLOW}Action needed on Windows:${RESET}
  Fast:    double-click C:\\wisdom-project\\restart.bat
  Manual:  Ctrl+C the cmd window running serve-web.bat → press Y → rerun serve-web.bat

Waiting for /healthz to report sha=${GIT_SHA}...

EOF

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
