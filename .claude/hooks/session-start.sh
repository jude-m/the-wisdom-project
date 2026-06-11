#!/bin/bash
# SessionStart hook for Claude Code on the web.
#
# Provisions the Flutter SDK and resolves project dependencies so that
# `flutter analyze`, `flutter test`, and codegen work inside the ephemeral
# remote container. Runs ONLY in remote (web) sessions — it is a no-op on a
# developer's local machine.
set -euo pipefail

# Only run in Claude Code on the web. On a local machine the developer already
# has their own Flutter toolchain, so we must not interfere with it.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Run asynchronously: the session starts immediately while this provisions the
# Flutter SDK and dependencies in the background. Timeout is generous to cover a
# cold SDK download (~1GB) on a fresh container.
echo '{"async": true, "asyncTimeout": 600000}'

FLUTTER_VERSION="3.44.1"
FLUTTER_HOME="${HOME}/.flutter-sdk"
FLUTTER_BIN="${FLUTTER_HOME}/flutter/bin"
ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${ARCHIVE}"

# 1. Install the Flutter SDK (idempotent — skips if already cached).
if [ ! -x "${FLUTTER_BIN}/flutter" ]; then
  echo "[session-start] Installing Flutter ${FLUTTER_VERSION}..."
  mkdir -p "${FLUTTER_HOME}"
  curl -fSL --retry 4 --retry-delay 2 -o "/tmp/${ARCHIVE}" "${URL}"
  tar -xJf "/tmp/${ARCHIVE}" -C "${FLUTTER_HOME}"
  rm -f "/tmp/${ARCHIVE}"
else
  echo "[session-start] Flutter ${FLUTTER_VERSION} already present — skipping download."
fi

# Flutter ships as a git checkout; mark it safe so it works when owned by root.
git config --global --add safe.directory "${FLUTTER_HOME}/flutter" || true

export PATH="${FLUTTER_BIN}:${PATH}"

# Persist PATH for the rest of the session so Claude can invoke flutter/dart.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"${FLUTTER_BIN}:\$PATH\"" >> "${CLAUDE_ENV_FILE}"
fi

# Pre-cache the Flutter/Dart artifacts and disable analytics (non-interactive).
flutter config --no-analytics >/dev/null 2>&1 || true
flutter precache --no-android --no-ios --no-web --no-linux --no-windows --no-macos --no-fuchsia >/dev/null 2>&1 || true

# 2. Resolve dependencies for the app and its sibling Dart packages.
echo "[session-start] Running flutter pub get..."
flutter pub get

if [ -f "${CLAUDE_PROJECT_DIR}/packages/wisdom_shared/pubspec.yaml" ]; then
  echo "[session-start] pub get: packages/wisdom_shared"
  (cd "${CLAUDE_PROJECT_DIR}/packages/wisdom_shared" && dart pub get) || true
fi
if [ -f "${CLAUDE_PROJECT_DIR}/server/pubspec.yaml" ]; then
  echo "[session-start] pub get: server"
  (cd "${CLAUDE_PROJECT_DIR}/server" && dart pub get) || true
fi

# 3. Provide placeholder DB assets if missing.
# The SQLite databases (assets/databases/*.db) are large, git-ignored, generated
# artifacts (built via tools/*.js) and are never present in a fresh clone. Flutter
# fails the asset-bundle build for ANY `flutter test` run when a declared asset is
# missing, so we create empty placeholders. Tests that exercise real FTS/dictionary
# content need the real DBs regenerated; the bulk of unit/widget tests do not.
DB_DIR="${CLAUDE_PROJECT_DIR}/assets/databases"
mkdir -p "${DB_DIR}"
for db in bjt-fts.db dict.db; do
  if [ ! -f "${DB_DIR}/${db}" ]; then
    echo "[session-start] Creating placeholder asset: assets/databases/${db}"
    : > "${DB_DIR}/${db}"
  fi
done

# 4. Run code generation (Freezed / json_serializable) required before tests.
echo "[session-start] Running build_runner codegen..."
dart run build_runner build --delete-conflicting-outputs

echo "[session-start] Environment ready."
