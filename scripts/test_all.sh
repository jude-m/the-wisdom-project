#!/bin/bash
# Test every product, or the ones named, through each product's own test.sh.
#
# Usage:
#   ./scripts/test_all.sh                        # every product's test.sh
#   ./scripts/test_all.sh app static_site        # only these
#   ./scripts/test_all.sh --quick                # passes --quick to each
#   -h, --help
#
# Products: app, static_site, research_server.
#
# Keeps going after a failure, then prints one line per product and exits 1 if
# any failed. No test logic of its own: wisdom_shared runs inside both app and
# static_site, the price of each product standing alone.
# END-USAGE

. "$(dirname "$0")/lib/common.sh"

# Every product with a test.sh, in run order. A new product is added here.
ALL_PRODUCTS=(app static_site research_server)

QUICK_ARGS=()
PRODUCTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quick)   QUICK_ARGS=(--quick); shift ;;
    -h|--help) usage ;;
    -*)
      echo "Unknown option: $1" >&2
      echo "Run with -h for help." >&2
      exit 1
      ;;
    *)
      case " ${ALL_PRODUCTS[*]} " in
        *" $1 "*) PRODUCTS+=("$1"); shift ;;
        *)
          echo "Unknown product: $1 (one of: ${ALL_PRODUCTS[*]})." >&2
          exit 1
          ;;
      esac
      ;;
  esac
done

[ ${#PRODUCTS[@]} -gt 0 ] || PRODUCTS=("${ALL_PRODUCTS[@]}")

for product in "${PRODUCTS[@]}"; do
  run_step "$product" "$WISDOM_ROOT/scripts/$product/test.sh" "${QUICK_ARGS[@]}"
done

if [ ${#QUICK_ARGS[@]} -gt 0 ]; then
  step_summary "test_all (--quick)"
else
  step_summary "test_all"
fi
