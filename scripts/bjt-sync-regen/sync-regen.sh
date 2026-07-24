#!/bin/bash
# Sync + regenerate the app's vendored canon text from the upstream tipitaka.lk project.
#
# The app ships its OWN copies of the Pali/Sinhala canon (assets/text/*.json +
# assets/data/tree.json). This script pulls the latest corrections from a local
# read-only mirror of pathnirvana/tipitaka.lk and copies them into those assets,
# leaving a provenance receipt so "are we stale?" becomes a one-line SHA compare.
#
# Full background + rationale: docs/todo/bjt-sync-regen.md
#
# What it does (the pipeline; later steps only run if earlier ones changed things):
#   Step 0  Heartbeat  — ask GitHub for upstream's latest SHA, compare to receipt.
#   Step 1  Pull       — fast-forward the read-only mirror.
#   Step 2  Review     — show the correction commits since our last sync.
#   Step 3  tree.json  — diff the navigation map SEPARATELY & LOUDLY (nodeKeys!).
#   Step 4  Copy       — copy the new text + tree.json into assets/.
#   Step 5  Rebuild    — ask y/n to regenerate the static HTML (stub) and FTS db (real).
#   Step 6  Receipt    — record upstream SHA + date + file count next to this script.
#
# Usage:
#   ./scripts/bjt-sync-regen/sync-regen.sh              # interactive sync
#   ./scripts/bjt-sync-regen/sync-regen.sh --dry-run    # heartbeat + diffs only, touch nothing
#   ./scripts/bjt-sync-regen/sync-regen.sh --force      # sync even if the heartbeat says up to date
#   ./scripts/bjt-sync-regen/sync-regen.sh -h           # this help
#
# The mirror location is a variable — override it on a different machine with:
#   TIPITAKA_MIRROR=/path/to/tipitaka.lk-readonly ./scripts/bjt-sync-regen/sync-regen.sh
#
# House rules for the mirror: pull only, never commit, never add a remote to it.
#
# Exit codes:  0 = synced OK (or --dry-run / --help completed)
#             10 = already up to date, nothing to do
#             20 = aborted by you (deletion gate, or copy declined)
#              1 = error (bad mirror, no network, bad option)

set -euo pipefail

# --- Config (override via env) ---------------------------------------------
UPSTREAM_URL="${TIPITAKA_UPSTREAM_URL:-https://github.com/pathnirvana/tipitaka.lk.git}"
UPSTREAM_BRANCH="${TIPITAKA_UPSTREAM_BRANCH:-master}"
# The read-only mirror. Default assumes it sits beside the project in Desktop/Dev,
# but any machine can point elsewhere with $TIPITAKA_MIRROR (see Usage above).
MIRROR="${TIPITAKA_MIRROR:-$HOME/Desktop/Dev/tipitaka.lk-readonly}"

# --- Parse args -------------------------------------------------------------
DRY_RUN=0
FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --force)   FORCE=1;   shift ;;
    -h|--help)
      # Print the header comment block (lines 2..first non-comment) as help, then exit.
      # Driven by an end-marker, not hardcoded line numbers, so it survives header edits.
      awk 'NR==1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: ./scripts/bjt-sync-regen/sync-regen.sh [--dry-run | --force]"
      exit 1
      ;;
  esac
done

# Project root is two levels up: scripts/bjt-sync-regen/ -> scripts/ -> project.
cd "$(dirname "$0")/../.."
ROOT="$(pwd)"

# Paths inside the mirror (source) and the app (destination).
MIRROR_TEXT="$MIRROR/public/static/text"
MIRROR_DATA="$MIRROR/public/static/data"
MIRROR_TREE="$MIRROR_DATA/tree.json"
DEST_TEXT="$ROOT/assets/text"
DEST_DATA="$ROOT/assets/data"
DEST_TREE="$DEST_DATA/tree.json"
RECEIPT="$ROOT/scripts/bjt-sync-regen/bjt-provenance.json"

# Data files (public/static/data) we vendor besides the 285 text files. tree.json is
# guarded loudly on its own (Step 3); the other two are plain metadata the app also
# ships (both declared in pubspec.yaml). We deliberately SKIP the -new/-old variants of
# footnote-abbreviations — those are outputs of upstream's dev/footnotes error-check,
# not sources we ship.
DATA_FILES=(tree.json file-map.json footnote-abbreviations.json)
# The same, as repo-relative paths, for the closing report + dirty-tree warning.
DATA_REPORT_PATHS=()
for _f in "${DATA_FILES[@]}"; do DATA_REPORT_PATHS+=("assets/data/$_f"); done

# --- Small helpers ----------------------------------------------------------
hr()  { printf '%s\n' "------------------------------------------------------------"; }
step(){ echo; hr; echo "$1"; hr; }

# Bold / highlight codes for scary warnings — only when writing to a real terminal
# (so piping the output to a file/log doesn't fill it with escape gibberish).
if [ -t 1 ]; then
  BOLD="$(printf '\033[1m')"; HILITE="$(printf '\033[1;97;41m')"; RESET="$(printf '\033[0m')"
else
  BOLD=""; HILITE=""; RESET=""
fi

# Ask a yes/no question. Returns 0 for yes, 1 for no. Defaults to No on empty.
# Reads from the controlling terminal (/dev/tty), NOT the script's stdin. If we read
# from stdin and it is a pipe / IDE run-box / already exhausted, `read` hits EOF and
# silently answers "No" to every remaining prompt — which is how a "no" to one question
# could skip the next (e.g. FTS). /dev/tty always points at the real keyboard.
confirm() {
  local reply=""
  if [ -e /dev/tty ]; then
    read -r -p "$1 [y/N] " reply </dev/tty || reply=""
  else
    echo "$1 [y/N]  (no terminal available for input — assuming No)"
  fi
  [[ "$reply" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]
}

# Read the last-synced upstream SHA out of the receipt (empty if no receipt yet).
receipt_sha() {
  [ -f "$RECEIPT" ] || return 0
  grep '"upstream_sha"' "$RECEIPT" | head -1 \
    | sed 's/.*"upstream_sha"[[:space:]]*:[[:space:]]*"\([0-9a-f]*\)".*/\1/'
}

# --- Sanity checks ----------------------------------------------------------
if [ ! -d "$MIRROR/.git" ]; then
  echo "error: read-only mirror not found at: $MIRROR"
  echo "       Clone it (blobless) or set \$TIPITAKA_MIRROR. See docs/todo/bjt-sync-regen.md."
  exit 1
fi
if [ ! -d "$MIRROR_TEXT" ] || [ ! -f "$MIRROR_TREE" ]; then
  echo "error: mirror is missing public/static/text or public/static/data/tree.json"
  echo "       Is \$TIPITAKA_MIRROR pointing at a real tipitaka.lk checkout? ($MIRROR)"
  exit 1
fi

echo "Project : $ROOT"
echo "Mirror  : $MIRROR"
echo "Upstream: $UPSTREAM_URL ($UPSTREAM_BRANCH)"
[ "$DRY_RUN" = 1 ] && echo "Mode    : DRY RUN (nothing will be copied or written)"

# ---------------------------------------------------------------------------
# Step 0 — Heartbeat: did anything change upstream? (no clone, one line)
# ---------------------------------------------------------------------------
step "Step 0 — Heartbeat: is upstream ahead of us?"
PREV_SHA="$(receipt_sha)"
# refs/heads/$BRANCH (not the bare name) so a same-named TAG can't add a second line;
# head -1 is belt-and-braces to keep REMOTE_SHA a single SHA.
REMOTE_SHA="$(git ls-remote "$UPSTREAM_URL" "refs/heads/$UPSTREAM_BRANCH" | head -1 | awk '{print $1}')"

if [ -z "$REMOTE_SHA" ]; then
  echo "error: could not reach upstream (no network?). Try again later."
  exit 1
fi

echo "Upstream latest : $REMOTE_SHA"
if [ -n "$PREV_SHA" ]; then
  echo "Last synced     : $PREV_SHA   (from receipt)"
else
  echo "Last synced     : (none — no receipt yet; treating this as the first sync)"
fi

if [ -n "$PREV_SHA" ] && [ "$PREV_SHA" = "$REMOTE_SHA" ]; then
  if [ "$FORCE" = 1 ]; then
    echo "Already up to date, but --force given — continuing anyway."
  else
    echo
    echo "Up to date. Nothing to sync. (Use --force to re-copy anyway.)"
    exit 10
  fi
fi

# ---------------------------------------------------------------------------
# Step 1 — Refresh the read-only mirror (fast-forward only)
# ---------------------------------------------------------------------------
step "Step 1 — Pull the read-only mirror"
if [ "$DRY_RUN" = 1 ]; then
  # A dry run must touch NOTHING — not even the mirror. Use its current HEAD, and note
  # the preview is against whatever the mirror already has, not necessarily upstream latest.
  echo "DRY RUN — not pulling the mirror. Previewing against its current HEAD."
  NEW_SHA="$(git -C "$MIRROR" rev-parse HEAD)"
else
  git -C "$MIRROR" pull --ff-only
  NEW_SHA="$(git -C "$MIRROR" rev-parse HEAD)"
  # Guard: the SHA we just pulled should match the one the heartbeat asked upstream for.
  # If not, the mirror tracks a different remote/branch than $UPSTREAM_URL — provenance
  # would record one repo while we synced from another.
  if [ "$NEW_SHA" != "$REMOTE_SHA" ]; then
    echo "warn: mirror HEAD ($NEW_SHA)"
    echo "      != upstream $UPSTREAM_BRANCH ($REMOTE_SHA) that the heartbeat queried."
    echo "      Check the mirror tracks $UPSTREAM_URL before trusting the receipt."
  fi
fi
echo "Mirror now at: $NEW_SHA"

# The baseline for our diffs is what we LAST synced (the receipt SHA), not the
# mirror's previous HEAD — the mirror may have been pulled on its own before.
OLD_SHA="$PREV_SHA"
HAVE_BASELINE=0
if [ -n "$OLD_SHA" ] && git -C "$MIRROR" cat-file -e "$OLD_SHA^{commit}" 2>/dev/null; then
  HAVE_BASELINE=1
fi

# ---------------------------------------------------------------------------
# Step 2 — Review the corrections (human step)
# ---------------------------------------------------------------------------
step "Step 2 — Review the corrections since our last sync"
if [ "$HAVE_BASELINE" = 0 ]; then
  echo "No usable baseline to diff against (first sync, or old SHA not in history)."
  echo "Skipping the correction review — the copy below brings in the full latest text."
else
  COMMIT_COUNT="$(git -C "$MIRROR" rev-list --count "$OLD_SHA..$NEW_SHA")"
  echo "$COMMIT_COUNT upstream commit(s) since our last sync:"
  echo
  git -C "$MIRROR" log --oneline "$OLD_SHA..$NEW_SHA"
  echo
  echo "For the full text diff, run:"
  echo "  git -C \"$MIRROR\" diff $OLD_SHA $NEW_SHA -- public/static/text"
fi

# ---------------------------------------------------------------------------
# Step 3 — tree.json guard: diff it SEPARATELY and LOUDLY (nodeKeys move!)
# ---------------------------------------------------------------------------
step "Step 3 — tree.json check (navigation map / nodeKeys)"
TREE_CHANGED=0
if [ "$HAVE_BASELINE" = 1 ]; then
  if git -C "$MIRROR" diff --quiet "$OLD_SHA" "$NEW_SHA" -- public/static/data/tree.json; then
    echo "tree.json: unchanged upstream. Safe."
  else
    TREE_CHANGED=1
  fi
else
  # No baseline: compare the file we currently ship against the mirror's copy.
  if ! cmp -s "$DEST_TREE" "$MIRROR_TREE"; then
    TREE_CHANGED=1
  else
    echo "tree.json: identical to what we already ship. Safe."
  fi
fi

if [ "$TREE_CHANGED" = 1 ]; then
  echo "!!  tree.json HAS CHANGED  !!"
  echo
  echo "tree.json assigns every section its nodeKey. nodeKeys feed deep-link URLs"
  echo "(/tipitaka/<nodeKey>) and the SuttaCentral<->BJT concordance. If a key MOVED,"
  echo "already-shared links can silently break. Review before accepting:"
  echo
  if [ "$HAVE_BASELINE" = 1 ]; then
    git -C "$MIRROR" diff --stat "$OLD_SHA" "$NEW_SHA" -- public/static/data/tree.json || true
    echo
    echo "Inspect the full change with:"
    echo "  git -C \"$MIRROR\" diff $OLD_SHA $NEW_SHA -- public/static/data/tree.json"
  else
    echo "  (no git baseline — compare the files directly:)"
    echo "  diff <(python3 -m json.tool \"$DEST_TREE\") <(python3 -m json.tool \"$MIRROR_TREE\")"
  fi
fi

# ---------------------------------------------------------------------------
# Step 4 — Copy the new source into the app
# ---------------------------------------------------------------------------
step "Step 4 — Copy text + tree.json into assets/"

# Count the mirror's text files (shown in the copy preview below). The guard against
# a wrong/empty mirror is the deletion gate further down — not a magic threshold: an
# empty/wrong mirror surfaces as "every vendored file would be deleted" and hard-stops.
MIRROR_JSON_COUNT="$(find "$MIRROR_TEXT" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')"

# Show exactly which text files are added / modified / deleted upstream.
if [ "$HAVE_BASELINE" = 1 ]; then
  echo "Text file changes upstream (A=added, M=modified, D=deleted):"
  git -C "$MIRROR" diff --name-status "$OLD_SHA" "$NEW_SHA" -- public/static/text || true
  echo
fi

# Authoritative deletion check: which files we currently ship would `rsync --delete`
# actually remove? = every file present under assets/text but absent from the mirror.
# We list ALL files (find, any extension, incl. dotfiles and sub-dirs), not just *.json
# — rsync --delete is that broad, so the gate must be too. Reads the filesystem (what
# rsync acts on), so it holds even on a first sync with no git baseline. Canon files
# disappearing is HIGHLY unlikely — treat any as a red flag.
TO_DELETE="$(comm -23 \
  <(cd "$DEST_TEXT"   && find . -type f 2>/dev/null | sort) \
  <(cd "$MIRROR_TEXT" && find . -type f 2>/dev/null | sort) || true)"
DELETE_COUNT="$(printf '%s' "$TO_DELETE" | grep -c . || true)"

if [ "$DRY_RUN" = 1 ]; then
  echo "DRY RUN — not copying. This is what a real run would bring in:"
  echo "  $MIRROR_TEXT/  ->  $DEST_TEXT/   ($MIRROR_JSON_COUNT files, mirrored)"
  echo "  $MIRROR_TREE   ->  $DEST_TREE"
  echo "  $MIRROR_DATA/{file-map,footnote-abbreviations}.json  ->  $DEST_DATA/"
  if [ "$DELETE_COUNT" -gt 0 ]; then
    echo
    printf '%s\n' "${HILITE} !!  WOULD DELETE $DELETE_COUNT VENDORED FILE(S) — HIGHLY UNUSUAL  !! ${RESET}"
    printf '%s\n' "$TO_DELETE" | sed 's/^/    - /'
    echo "(A real run would STOP here for explicit confirmation.)"
  fi
  echo
  echo "Re-run without --dry-run to apply."
  exit 0
fi

# --- Deletion gate: STOP immediately unless explicitly confirmed ------------
# Deletions are so unlikely they usually mean a wrong $TIPITAKA_MIRROR, not a real
# upstream removal. So this is a hard gate: bold-highlighted, and it stops unless the
# user types the full word "yes".
if [ "$DELETE_COUNT" -gt 0 ]; then
  echo
  printf '%s\n' "${HILITE} !!  STOP — $DELETE_COUNT VENDORED FILE(S) WOULD BE DELETED  !! ${RESET}"
  echo
  printf '%s\n' "${BOLD}These files are in the app but NOT in the mirror, so a sync would REMOVE them:${RESET}"
  printf '%s\n' "$TO_DELETE" | sed 's/^/    - /'
  echo
  echo "Canon files almost never disappear. If this is unexpected, stop now and check"
  echo "that \$TIPITAKA_MIRROR points at the right checkout/branch before anything else."
  echo
  reply=""
  if [ -e /dev/tty ]; then
    read -r -p "Type 'yes' to delete these and continue, anything else stops: " reply </dev/tty || reply=""
  fi
  if [ "$reply" != "yes" ]; then
    echo "Stopped. Nothing was changed."
    exit 20
  fi
fi

# Warn if the working tree already has local edits to the files we're about to
# overwrite. The last COMMITTED version is safe in git, but in-progress (uncommitted)
# edits are not — rsync/cp will clobber them. The copy confirm below lets you back out.
if [ -n "$(git status --porcelain -- "$DEST_TEXT" "${DATA_REPORT_PATHS[@]}" 2>/dev/null)" ]; then
  echo
  printf '%s\n' "${BOLD}Heads up: assets/ has uncommitted local changes that this sync will overwrite.${RESET}"
  echo "Committed versions are safe in git; in-progress edits are NOT — stash or commit them first to keep them."
fi

echo
echo "About to mirror:"
echo "  $MIRROR_TEXT/  ->  $DEST_TEXT/   ($MIRROR_JSON_COUNT files)"
echo "  $MIRROR_TREE   ->  $DEST_TREE"
echo "  $MIRROR_DATA/{file-map,footnote-abbreviations}.json  ->  $DEST_DATA/"
if [ "$TREE_CHANGED" = 1 ]; then
  echo
  echo "Reminder: tree.json changed (Step 3). Only continue if you reviewed the nodeKey diff."
fi
echo
if ! confirm "Copy these into assets/ now?"; then
  echo "Aborted before copying. Nothing was changed."
  exit 20
fi

# --delete keeps assets a faithful mirror. What makes it safe is the deletion gate
# above: any file that would be removed hard-stops the run unless explicitly confirmed.
rsync -a --delete "$MIRROR_TEXT/" "$DEST_TEXT/"
# tree.json + the other vendored data files (the -new/-old variants are skipped).
for f in "${DATA_FILES[@]}"; do
  if [ -f "$MIRROR_DATA/$f" ]; then
    cp "$MIRROR_DATA/$f" "$DEST_DATA/$f"
  else
    echo "  WARNING: $f is missing from the mirror — leaving the vendored copy untouched."
  fi
done

DEST_COUNT="$(find "$DEST_TEXT" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')"
echo "Copied. assets/text now has $DEST_COUNT JSON files; tree.json + data files updated."

# ---------------------------------------------------------------------------
# Step 5 — Rebuild what depends on the text  (STUBS — not wired up yet)
# ---------------------------------------------------------------------------
step "Step 5 — Rebuild downstream (optional)"
echo "The text changed, so two things MAY need regenerating. Both are asked, not automatic."
echo

# --- 5a. Static HTML site (stub) ---
if confirm "Regenerate the static HTML site?"; then
  # TODO: wire this once the generator exists.
  #       See docs/todo/web-strategy/static-html-site-plan.md
  echo "  [stub] Static HTML generator is not built yet — skipping."
  echo "  [stub] Track it in docs/todo/web-strategy/static-html-site-plan.md"
else
  echo "  Skipped static HTML regeneration."
fi
echo

# --- 5b. FTS database (real) ---
if confirm "Regenerate the FTS database (bjt-fts.db, ~114 MB heavy rebuild)?"; then
  echo "  Regenerating bjt-fts.db — indexing ~457k entries into assets/databases/;"
  echo "  this takes a few minutes..."
  # Run from tools/ (the generator reads ../assets/text and writes assets/databases/bjt-fts.db).
  # Wrapped in `if` so a failure only warns instead of aborting the script (set -e).
  if ( cd tools && { [ -d node_modules ] || npm install; } && npm run generate-fts ); then
    echo "  FTS database rebuilt: assets/databases/bjt-fts.db"
  else
    echo "  WARNING: FTS regeneration FAILED — bjt-fts.db may be stale."
    echo "           Run it by hand to see the error: cd tools && npm run generate-fts"
  fi
else
  echo "  Skipped FTS regeneration — bjt-fts.db is now STALE until you run: cd tools && npm run generate-fts"
fi

# ---------------------------------------------------------------------------
# Step 6 — Write the provenance receipt (so Step 0 has something to compare)
# ---------------------------------------------------------------------------
step "Step 6 — Write the provenance receipt"
SYNCED_ON="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat > "$RECEIPT" <<EOF
{
  "source": "$UPSTREAM_URL",
  "branch": "$UPSTREAM_BRANCH",
  "upstream_sha": "$NEW_SHA",
  "synced_on": "$SYNCED_ON",
  "text_file_count": $DEST_COUNT
}
EOF
echo "Wrote $RECEIPT"
echo "  upstream_sha : $NEW_SHA"
echo "  synced_on    : $SYNCED_ON"
echo "  text_files   : $DEST_COUNT"

# ---------------------------------------------------------------------------
# Sync report — what this run actually did
# ---------------------------------------------------------------------------
step "Sync report"

# (a) The upstream commits incorporated during this run.
echo "Upstream commits incorporated this run:"
if [ "$HAVE_BASELINE" = 1 ]; then
  git -C "$MIRROR" log --oneline "$OLD_SHA..$NEW_SHA" | sed 's/^/    /'
  echo "    (${COMMIT_COUNT} commit(s):  ${OLD_SHA:0:12} -> ${NEW_SHA:0:12})"
else
  echo "    Initial import — full snapshot at ${NEW_SHA:0:12} (no prior baseline to range from)."
  echo "    Latest upstream commits, for context:"
  git -C "$MIRROR" log --oneline -10 | sed 's/^/      /'
fi
echo

# (b) Pending changes in the synced paths, read back from git (working tree vs last
#     commit), so it reflects reality — modified / added / deleted — including the
#     receipt just written. NOTE: this is the working-tree state of these paths, so any
#     edits you already had before this run show up here too (the dirty-tree warning in
#     Step 4 flags that up front). The list is capped; the counts are always complete.
echo "Pending changes in synced paths (M=modified, A=added, D=deleted):"
REPORT_STAT="$(git -c core.quotepath=false status --porcelain \
  -- "$DEST_TEXT" "${DATA_REPORT_PATHS[@]}" "$RECEIPT" 2>/dev/null || true)"
if [ -z "$REPORT_STAT" ]; then
  echo "    (no changes — assets already matched the mirror)"
else
  CAP=40
  # Porcelain codes → a simple label ('??' untracked shown as A=added). substr keeps the
  # whole path even if it contains spaces. Cap + overflow line are done inside awk over a
  # here-string (no `head` pipe → no SIGPIPE/pipefail abort if the list is ever huge).
  awk -v cap="$CAP" '
    { c=$1; if(c=="??") c="A"; p=substr($0, index($0,$2))
      if (NR<=cap) printf "    %s  %s\n", c, p }
    END { if (NR>cap) printf "    ... and %d more (full counts below).\n", NR-cap }
  ' <<< "$REPORT_STAT"
  MOD=$(printf '%s\n' "$REPORT_STAT" | awk '$1=="M"{n++}  END{print n+0}')
  DEL=$(printf '%s\n' "$REPORT_STAT" | awk '$1=="D"{n++}  END{print n+0}')
  ADD=$(printf '%s\n' "$REPORT_STAT" | awk '$1=="??"{n++} END{print n+0}')
  echo "    Summary: $MOD modified, $ADD added, $DEL deleted."
fi
echo

hr
echo "Done. Review the report above, then commit when happy:"
echo "  git add assets/ scripts/bjt-sync-regen/bjt-provenance.json && git commit -m \"chore(canon): sync BJT text to ${NEW_SHA:0:12}\""
hr
exit 0
