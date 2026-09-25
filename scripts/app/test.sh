#!/bin/bash
# The app's release gate: format, generated code, analyze, unit and widget
# tests, wisdom_shared, the shipped databases, and the integration suite on
# macOS and in Chrome.
#
# Usage:
#   ./scripts/app/test.sh            # everything
#   ./scripts/app/test.sh --quick    # leave out the databases and integration
#   -h, --help
#
# --quick leaves out every step that needs the built databases (gitignored,
# built from tools/), macOS or Chrome; it is what CI runs on every push.
# Without it every step must run — a missing database or browser is a FAIL,
# not a skip.
#
# Runs every step even after one fails, then prints a summary and exits 0 or 1.
# The generated-code step may rewrite generated files: a changed file is what
# it reports, so commit the regen.
# END-USAGE

. "$(dirname "$0")/../lib/common.sh"

QUICK=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quick)   QUICK=true; shift ;;
    -h|--help) usage ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Run with -h for help." >&2
      exit 1
      ;;
  esac
done

cd "$WISDOM_ROOT" || exit 1

DART_DIRS=(lib test integration_test test_driver tools packages/wisdom_shared)

# Every generated file git keeps, with its hash; a file added or removed changes
# it too. The gitignored Mockito output is left out, so a fresh clone that lacks
# it isn't "stale".
generated_hashes() {
  git ls-files --cached --others --exclude-standard -- \
    '*.g.dart' '*.freezed.dart' '*.mocks.dart' \
    'lib/core/localization/l10n/app_localizations*.dart' |
    LC_ALL=C sort | xargs shasum -a 256
}

# Taken before any step: `flutter pub get` runs gen-l10n by itself
# (`generate: true`), which would hide a stale localization file.
GENERATED_BEFORE=$(generated_hashes)

dependencies() {
  flutter pub get &&
    (cd packages/wisdom_shared && dart pub get)
}

format() {
  dart format --output=none --set-exit-if-changed "${DART_DIRS[@]}"
}

analyze() {
  flutter analyze "${DART_DIRS[@]}"
}

# Hashes, not `git diff`, so a fresh but uncommitted regen passes.
generated_code() {
  local after
  dart run build_runner build --delete-conflicting-outputs &&
    flutter gen-l10n &&
    after=$(generated_hashes) &&
    if [ "$GENERATED_BEFORE" != "$after" ]; then
      echo ""
      echo "Generated code was stale; the regen changed:"
      diff <(echo "$GENERATED_BEFORE") <(echo "$after") |
        sed -n 's/^[<>] [0-9a-f]*  /  /p' | sort -u
      false
    fi
}

unit_and_widget() {
  flutter test
}

shared_tests() {
  cd packages/wisdom_shared && dart test
}

# Each database the manifest names: present, a SQLite file, not WAL-flagged
# (the wasm build rejects that as "file is not a database"), and the hash the
# manifest records — a phone keeps its old copy of a database whose file
# changed without its hash. A database the manifest leaves out fails too: the
# app throws on opening it.
shipped_databases() {
  local dir=assets/databases manifest=assets/databases/manifest.json
  local failed=0 bad name db expected actual write_ver read_ver
  if [ ! -f "$manifest" ]; then
    echo "$manifest is missing. Build the databases: cd tools && npm run generate-bjt && npm run generate-dict"
    return 1
  fi
  # An empty or broken manifest checks nothing, so fail instead of passing.
  # jq -e fails on false or on invalid JSON.
  if ! jq -e 'length > 0' "$manifest" >/dev/null 2>&1; then
    echo "✗ $manifest is empty or not valid JSON"
    return 1
  fi
  for db in "$dir"/*.db; do
    [ -f "$db" ] || continue
    name=$(basename "$db")
    if [ -z "$(jq -r --arg n "$name" '.[$n].sha256 // empty' "$manifest")" ]; then
      echo "✗ $name has no entry in $manifest"
      failed=1
    fi
  done
  for name in $(jq -r 'keys[]' "$manifest"); do
    db="$dir/$name"
    bad=0
    if [ ! -f "$db" ]; then
      echo "✗ $name is missing"
      failed=1
      continue
    fi
    # Magic first: od on a too-short file prints a complaint of its own.
    if [ "$(head -c 15 "$db")" != "SQLite format 3" ]; then
      echo "✗ $name is not a SQLite database"
      failed=1
      continue
    fi
    # Header bytes 18/19 are the write/read versions; 2 means WAL.
    write_ver=$(od -An -tu1 -j18 -N1 "$db" | xargs)
    read_ver=$(od -An -tu1 -j19 -N1 "$db" | xargs)
    if [ "${write_ver:-9}" -gt 1 ] || [ "${read_ver:-9}" -gt 1 ]; then
      echo "✗ $name is WAL-flagged (bytes 18/19 = $write_ver/$read_ver). Rebuild it from tools/."
      bad=1
    fi
    expected=$(jq -r --arg n "$name" '.[$n].sha256 // empty' "$manifest")
    actual=$(shasum -a 256 "$db" | cut -d' ' -f1)
    if [ "$expected" != "$actual" ]; then
      echo "✗ $name does not match its manifest hash. Rebuild it from tools/."
      bad=1
    fi
    if [ $bad -eq 0 ]; then echo "✓ $name"; else failed=1; fi
  done
  return $failed
}

integration_macos() {
  flutter test integration_test/all_tests.dart -d macos
}

# Its own launch: it swaps a database file, so it can't share the suite's.
database_copy() {
  flutter test integration_test/bundled_database_copy_test.dart -d macos
}

integration_chrome() {
  ./scripts/app/web/test_chrome.sh
}

run_step "dependencies" dependencies
run_step "format" format
# Before analyze: the tests import the gitignored Mockito output, which a fresh
# clone only has once build_runner has run.
run_step "generated code is current" generated_code
run_step "analyze" analyze
run_step "unit + widget tests" unit_and_widget
run_step "wisdom_shared tests" shared_tests
if [ "$QUICK" = false ]; then
  run_step "shipped databases" shipped_databases
  run_step "integration · macOS" integration_macos
  # Not written yet: docs/todo/retiring-dart-server/bundled-database-copy-tests.md.
  # Once it exists, drop the `if`, so a renamed file fails instead of skipping.
  if [ -f integration_test/bundled_database_copy_test.dart ]; then
    run_step "database copy · macOS" database_copy
  else
    COPY_TEST_MISSING=true
  fi
  run_step "integration · Chrome" integration_chrome
fi

if [ "$QUICK" = true ]; then
  step_summary "app (--quick)"
else
  step_summary "app"
fi
status=$?

# After the summary, where the Chrome step's output can't bury it.
if [ "$COPY_TEST_MISSING" = true ]; then
  echo ""
  echo "${BOLD}Note:${NC} integration_test/bundled_database_copy_test.dart is not written yet;"
  echo "      this gate runs it once it exists."
fi
exit $status
