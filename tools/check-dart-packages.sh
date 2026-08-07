#!/bin/bash
# Analyze and test every pure-Dart package in one pass.
#
# `dart` cannot cross package boundaries — each resolves its own deps — so this
# can only be a loop that cd's into each one. Callers: tools/validate-release.sh,
# scripts/web/deploy.sh (Phase 2), scripts/bjt-sync-regen/sync-regen.sh (Step 5,
# where a re-sync of assets/ can move the static site's page budget with no code
# change at all).
#
# The Flutter app is not here — different runner, needs a device for integration:
#   flutter test
#   flutter test integration_test/all_tests.dart -d macos
#
# Usage:
#   ./tools/check-dart-packages.sh              # everything, ~35s
#   ./tools/check-dart-packages.sh -x corpus    # skip the 340 MB corpus checks
#
# Args go to `dart test` in EVERY package, so pass only what means something in
# all of them: -t/-x, -j, --reporter. Not a file path — it fails wherever that
# file doesn't exist; cd into the package for that.
#
# A package here must HAVE tests: `dart test` errors on an empty test/, and that
# is the point. Skipping them with a warning is how `server` sat test-less inside
# a gate that claimed to test it.

set -u
cd "$(dirname "$0")/.." || exit 1

packages="packages/wisdom_shared static_site_generator server"
failed=""

for pkg in $packages; do
  echo ""
  echo "── $pkg"
  # `pub get` first so imports resolve on a fresh checkout (idempotent). No
  # `set -e`: one package failing shouldn't hide the state of the rest.
  (
    cd "$pkg" &&
      dart pub get >/dev/null &&
      dart analyze &&
      dart test "$@"
  ) || failed="$failed $pkg"
done

echo ""
if [ -z "$failed" ]; then
  echo "PASS — all packages analyzed and tested"
else
  echo "FAILED:$failed"
  exit 1
fi
