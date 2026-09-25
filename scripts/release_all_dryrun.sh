#!/bin/bash
# Prove every target still deploys, without releasing anything: each target's
# deploy.sh once, `--dev --dry-run`, then one summary.
#
# Usage:
#   ./scripts/release_all_dryrun.sh            # the dry-run sweep
#   ./scripts/release_all_dryrun.sh --list     # every target, live or placeholder
#   -h, --help
#
# Never a release: it passes no other flags and takes no target, so it cannot
# reach prod or upload. To release, run that target's own deploy.sh, e.g.
# ./scripts/static_site/deploy.sh --prod.
#
# Keeps going after a failure and prints PASS, FAIL or NOT SET UP (a
# placeholder's exit 3) for each target; exits 1 only on a FAIL. An exit that
# disagrees with the header's dev= is a FAIL. Nothing checks prod=.
#
# Never run it while a static-site deploy is uploading: it rebuilds
# static_site_generator/build/ under that upload.
#
# --list reads the `# Status: dev=… prod=…` line in each deploy.sh header,
# because running a live deploy.sh to ask would start its tests.
# END-USAGE

. "$(dirname "$0")/lib/common.sh"

# Every target with a deploy.sh, named by its folder under scripts/, in sweep
# order. A new target is added here.
TARGETS=(static_site research_server app/web app/android app/ios app/macos)

deploy_script() {
  printf '%s' "$WISDOM_ROOT/scripts/$1/deploy.sh"
}

# `status_of TARGET dev|prod` — live or placeholder, from the header line.
status_of() {
  local value
  value=$(sed -n "s/^# Status:.*$2=\([a-z]*\).*/\1/p" "$(deploy_script "$1")")
  printf '%s' "${value:-unknown}"
}

list_targets() {
  local t
  printf '%-18s %-12s %s\n' "target" "dev" "prod"
  for t in "${TARGETS[@]}"; do
    printf '%-18s %-12s %s\n' "$t" "$(status_of "$t" dev)" "$(status_of "$t" prod)"
  done
}

# `sweep_step NAME COMMAND...` — run_step with a third state: exit 3 is
# NOT SET UP, neither a pass nor a failure. The exit must also match the header:
# 0 needs dev=live and 3 needs dev=placeholder, or it is a FAIL, so --list never
# goes stale. Kept out of run_step so no test.sh can ever read a 3 as a pass.
_LINES=()
_FAILED=0
sweep_step() {
  local name="$1" start status word colour header
  shift
  echo ""
  echo "${BOLD}── $name${NC}"
  start=$SECONDS
  "$@"
  status=$?
  header=$(status_of "$name" dev)
  case "$status:$header" in
    0:live)        word="PASS";       colour="$GREEN" ;;
    3:placeholder) word="NOT SET UP"; colour="" ;;
    0:*|3:*)
      word="FAIL"; colour="$RED"; _FAILED=1
      echo "error: $name exited $status but its header says dev=$header." >&2
      ;;
    *)             word="FAIL";       colour="$RED"; _FAILED=1 ;;
  esac
  # Padded before the colour codes go on, so the time column lines up.
  _LINES+=("$(printf '%-28s %s%-10s%s  %4ss' "$name" "$colour" "$word" "$NC" $((SECONDS - start)))")
}

sweep() {
  local t line
  for t in "${TARGETS[@]}"; do
    # Both flags said out loud, so a deploy.sh whose default ever changed
    # still gets a dev dry run.
    sweep_step "$t" "$(deploy_script "$t")" --dev --dry-run
  done
  echo ""
  echo "${BOLD}── release_all_dryrun (dev)${NC}"
  for line in "${_LINES[@]}"; do
    echo "$line"
  done
  exit $_FAILED
}

case "$#:${1-}" in
  0:)               sweep ;;
  1:--list)         list_targets ;;
  1:-h|1:--help)    usage ;;
  *)
    echo "error: release_all_dryrun.sh takes no target and no flags but --list." >&2
    echo "       To release, run the target's own deploy.sh, e.g." >&2
    echo "       ./scripts/static_site/deploy.sh --prod" >&2
    exit 1
    ;;
esac
