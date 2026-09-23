#!/bin/bash
# The research server's release gate: a TypeScript typecheck. `wrangler deploy`
# strips types without checking them, so without this a type error ships.
# There are no tests yet — writing them is its own task.
#
# Usage:
#   ./scripts/research_server/test.sh            # everything
#   ./scripts/research_server/test.sh --quick    # the same: nothing here needs
#                                                # more than a checkout
#   -h, --help
#
# Runs every step even after one fails, then prints a summary and exits 0 or 1.
# Called first by ./scripts/research_server/deploy.sh.
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

cd "$WISDOM_ROOT/research_server" || exit 1

require_node22

typecheck() {
  npm run typecheck
}

run_step "dependencies" research_deps
run_step "typecheck" typecheck

if [ "$QUICK" = true ]; then
  step_summary "research_server (--quick)"
else
  step_summary "research_server"
fi
