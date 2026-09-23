#!/bin/bash
# The static site's release gate: format, analyze and test the generator and
# the package it shares with the app. Plain `dart` only — no Flutter SDK.
#
# Usage:
#   ./scripts/static_site/test.sh            # everything
#   ./scripts/static_site/test.sh --quick    # leave out the corpus checks
#   -h, --help
#
# --quick leaves out the slow step; it is what CI runs on every push. Without
# it the corpus step reads assets/text (committed) and must run — a missing
# corpus is a FAIL, not a skip.
#
# Runs every step even after one fails, then prints a summary and exits 0 or 1.
# Called first by ./scripts/static_site/deploy.sh. Link checking is not here:
# it checks a build, and building is the deploy's job.
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

# `pub get` first so imports resolve on a fresh checkout.
dependencies() {
  (cd packages/wisdom_shared && dart pub get) &&
    (cd static_site_generator && dart pub get)
}

format() {
  dart format --output=none --set-exit-if-changed \
    static_site_generator packages/wisdom_shared
}

# --fatal-infos: `flutter analyze`, which used to be the only analyzer these
# packages saw, fails on infos too.
analyze() {
  (cd packages/wisdom_shared && dart analyze --fatal-infos) &&
    (cd static_site_generator && dart analyze --fatal-infos)
}

shared_tests() {
  cd packages/wisdom_shared && dart test
}

# From static_site_generator/: two paths in its suite are relative to the
# working directory, and the root pubspec has no `test` dependency. The wiring
# contract runs before the corpus, so a markup ⇄ stylesheet break shows first.
wiring_contract() {
  cd static_site_generator && dart test -x corpus
}

corpus() {
  cd static_site_generator && dart test -t corpus
}

run_step "dependencies" dependencies
run_step "format" format
run_step "analyze" analyze
run_step "wisdom_shared tests" shared_tests
run_step "wiring contract" wiring_contract
if [ "$QUICK" = false ]; then
  run_step "corpus" corpus
fi

if [ "$QUICK" = true ]; then
  step_summary "static_site (--quick)"
else
  step_summary "static_site"
fi
