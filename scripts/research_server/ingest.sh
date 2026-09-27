#!/bin/bash
# Upload SuttaCentral's bilara-data into a Gemini File Search store, for the
# research_server. Runs tools/research_ingest/ingest.py with the key from
# scripts/config/secrets.env (RESEARCH_GEMINI_API_KEY) and passes every
# argument through: `--help` lists them. A dry run needs no key.
#
# Usage:
#   ./scripts/research_server/ingest.sh --dry-run --filter sn/sn6/
#   ./scripts/research_server/ingest.sh --display-name <name> \
#       --chunk-tokens 200 --overlap-tokens 20        # new store, prints its id
#   ./scripts/research_server/ingest.sh --store fileSearchStores/<id> ...
#
# The venv, once, by hand:
#   python3 -m venv tools/research_ingest/.venv
#   tools/research_ingest/.venv/bin/pip install -r tools/research_ingest/requirements.txt
# END-USAGE

set -e

. "$(dirname "$0")/../lib/common.sh"

GEMINI_API_KEY=$(secret RESEARCH_GEMINI_API_KEY)
export GEMINI_API_KEY
exec "$WISDOM_ROOT/tools/research_ingest/.venv/bin/python" \
  "$WISDOM_ROOT/tools/research_ingest/ingest.py" "$@"
