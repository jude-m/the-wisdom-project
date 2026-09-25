#!/bin/bash
# Deploy the app's web build: Flutter web, to Cloudflare.
#
# Usage:
#   ./scripts/app/web/deploy.sh [--dev | --prod] [--dry-run] [--skip-tests] [--yes]
#   -h, --help
#
# Status: dev=placeholder prod=placeholder
#
# A PLACEHOLDER: this target is not set up yet. Every run prints why and exits
# 3 before any test, so scripts/release_all_dryrun.sh reports it as NOT SET
# UP, never as a pass. The flags are the ones every deploy.sh takes, so a
# caller's command line already works when this becomes real.
# END-USAGE

. "$(dirname "$0")/../../lib/common.sh"

TARGET="dev"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dev)        TARGET="dev";  shift ;;
    --prod)       TARGET="prod"; shift ;;
    --dry-run|--skip-tests|--yes|-y) shift ;;
    -h|--help)    usage ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Run with -h for help." >&2
      exit 1
      ;;
  esac
done

echo "app web --$TARGET is not set up yet:"
echo "  where Flutter web lives on Cloudflare is not decided — dev has no home,"
echo "  prod will be app.sammaditthi.net (docs/todo/web-strategy/web-release.md §6)."
exit 3
