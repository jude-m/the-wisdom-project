# BJT Sync + Regen — Update Script Plan

> Status: **Script built (2026-07-23), verify step added 2026-08-06.** The read-only
> sync source is set up, and `scripts/bjt-sync-regen/sync-regen.sh` does Steps 0–5 + 7
> for real, plus a closing sync report. Step 6b (FTS regen) is **wired** (real
> `npm run generate-fts`); Step 6a (static HTML) stays a **stub** until the generator
> exists.
> Scope: how the app's vendored canon text stays in step with the upstream
> tipitaka.lk project, and the script that does it.
>
> **Run it:** `./scripts/bjt-sync-regen/sync-regen.sh` (add `--dry-run` to preview,
> `--force` to re-copy when already up to date). The mirror path is overridable via
> `$TIPITAKA_MIRROR`.

---

## 1. The problem in one line

The app ships **its own copies** of the canon text. Those copies were hand-pasted
months ago and have **no record of where they came from or how old they are**, so
"are we out of date?" is currently impossible to answer without archaeology.

---

## 2. The three copies (do not confuse them)

There are three separate copies of the Pali/Sinhala text. Most of the past
confusion came from mixing them up.

| # | Where | What it is | Role |
|---|-------|-----------|------|
| 1 | GitHub `pathnirvana/tipitaka.lk` | The **parent project**. Maintainers apply corrections here. | Source of truth |
| 2 | `Desktop/Dev/tipitaka.lk-ios` | Our **fork clone**, for iOS app work only. | NOT in this pipeline |
| 3 | `the-wisdom-project/assets/text/` + `assets/data/tree.json` | The app's **vendored copy** (285 JSON files, ~340 MB, committed to git). | What the app actually reads |

Key facts:

- The app reads copy **#3**. `tools/bjt-fts-populate.js` reads it from `../assets/text/`.
- Copy #3 is **disconnected** — nothing links it back to #1. It was copied by hand.
- Best-guess vintage of #3 = ~September 2025 (the fork's last upstream merge, squashed
  into the 2025-12-03 initial commit, so git history can't tell us exactly).
- The fork (#2) is **iOS-only**. Its GitHub "Sync fork" button is useless to us — it
  only offers *discard our 797 commits* or *open a PR upstream*, neither of which
  touches copy #3. Ignore it.

---

## 3. The read-only sync source (DONE — set up 2026-07-23)

A dedicated, **read-only mirror** of the parent project:

```
Location : Desktop/Dev/tipitaka.lk-readonly
Remote   : https://github.com/pathnirvana/tipitaka.lk.git   (branch: master)
Clone    : git clone --filter=blob:none  (blobless)
Size     : ~780 MB   (.git 142 MB, full 786-commit history, flat layout)
```

Why this way:

- **Separate from the fork** so copies #2 and #3 can never get tangled again. This
  clone exists only to *read corrections out of* and copy them into copy #3.
- **Blobless** (`--filter=blob:none`) — keeps the **complete commit history** (every
  correction, every message) but skips old file *contents* until you actually diff
  something, then fetches them on demand. That is why `.git` is 142 MB not 561 MB.
- **Full, not shallow** — history is complete; nothing truncated.

House rules for this clone: **pull only, never commit, never add a remote to it.**
It is a mirror, not a workspace.

> ⚠️ **The `.lk` matters.** The upstream URL is `pathnirvana/tipitaka.**lk**.git`.
> The fork's old `upstream` remote pointed at `pathnirvana/tipitaka` (no `.lk`) —
> a repo that does not exist — which is why fetches there failed.

---

## 4. What the script must do (the steps)

The update is a pipeline. Later steps only run when an earlier step actually changes
something.

### Step 0 — Heartbeat: "did anything change?" (no download)

```bash
git ls-remote https://github.com/pathnirvana/tipitaka.lk.git master
```

Returns one line: the current upstream commit SHA. Compare it to the SHA in our
**receipt** (Step 7). Same → we are up to date, stop. Different → continue.

This needs **no clone** — it is the cheap check that can run often.

### Step 1 — Refresh the mirror

```bash
cd Desktop/Dev/tipitaka.lk-readonly
git pull            # fast-forward the read-only mirror to latest
```

### Step 2 — Review the corrections (human step)

Look at what changed before accepting it — this is canon text, so provenance matters.

```bash
git log --stat <old-sha>..<new-sha>          # what changed, with messages
git diff <old-sha> <new-sha> -- public/static/text   # the actual text edits
```

Expect commit messages like *"Errors sent by Bhante Bhaddacak (1–17)"* and
*"Error Corrections"*.

### Step 3 — ⚠️ Diff `tree.json` **separately and loudly**

`public/static/data/tree.json` is the navigation map — it assigns every section its
**nodeKey**. Those nodeKeys feed:

- deep-link URLs (`/tipitaka/<nodeKey>`), and
- the SuttaCentral ↔ BJT concordance.

Upstream has **"numbering changes and build tree"** commits, so keys can move. If a
key shifts and we blind-overwrite, **already-shared links silently break**. So:

```bash
git diff <old-sha> <new-sha> -- public/static/data/tree.json
```

Review this on its own. Never fold it into a bulk copy without looking.

### Step 4 — Copy the new source into the app

Copy from the mirror into the vendored copy (#3):

```
mirror  public/static/text/*.json                       →  wisdom  assets/text/*.json
mirror  public/static/data/tree.json                    →  wisdom  assets/data/tree.json
mirror  public/static/data/file-map.json                →  wisdom  assets/data/file-map.json
mirror  public/static/data/footnote-abbreviations.json  →  wisdom  assets/data/footnote-abbreviations.json
```

`file-map.json` (audio coverage index) and `footnote-abbreviations.json` (footnote
source sigla) are vendored too and are `cp`'d the same way — both are declared in
`pubspec.yaml`, so they must stay in step with upstream. Upstream's
`footnote-abbreviations-{new,old}.json` are error-check **outputs**, not sources, so
they are deliberately skipped.

The copy uses `rsync --delete`, so `assets/text` stays a faithful mirror. The guard
against a wrong/empty `$TIPITAKA_MIRROR` is the **deletion gate** (a magic file-count
floor is not needed — an empty/wrong mirror simply surfaces as "every vendored file
would be deleted", which trips the same gate):

- **Deletion gate (hard stop).** A canon file disappearing is highly unlikely and
  usually means the wrong mirror, not a real upstream removal. So if *any* vendored
  file would be removed, the script **bold-highlights it and stops**, continuing only
  if you type the full word `yes`. `--dry-run` surfaces the same warning without acting.

(TTS material, when that work starts, lives in the mirror's `dev/tts/` and
`dev/audio/` — see [tipitaka-tts-implementation-plan.md](./tipitaka-tts-implementation-plan.md).)

### Step 5 — Verify the new corpus (before anything is rebuilt on top of it)

```bash
./tools/check-dart-packages.sh
```

`dart analyze` + `dart test` across `packages/wisdom_shared`, `static_site_generator`
and `server` (~35s). It runs **before** the rebuilds on purpose.

The check that earns its place here is the static site's **page budget**. Grouping is
decided by a 1,500-character threshold, compared strictly less-than: `kn-thig-6`
measures exactly 1,500 and stays exploded because of it. A single character of
upstream correction can regroup a vagga, delete eight real URLs and shift every count
above it — and **nothing else in the pipeline would notice**, because the build still
succeeds and every link still resolves. It just isn't the site that was designed.

A failure **warns loudly and continues** rather than aborting, so a half-done sync
isn't lost. A locked figure moving is a decision, not a flake: read the `DRIFT` rows,
then either update `_locked` in `static_site_generator/tool/plan_corpus.dart`
along with the plan docs, or find out why it moved before rebuilding.

### Step 6 — Rebuild what depends on the text

Two things rebuild from the corrected JSON, **both asked (y/n), not automatic**:

1. **Static HTML site — ASK FIRST (stub).** Will regenerate from the corrected JSON
   once the generator exists
   (see [web-strategy/static-html-site-plan.md](./web-strategy/static-html-site-plan.md)).
   Prompt wired; body still a stub.
2. **FTS database — ASK FIRST (wired).** Runs `cd tools && npm run generate-fts` to
   regenerate `assets/databases/bjt-fts.db` (~114 MB, indexes ~457k entries; it is
   **gitignored**, so it's rebuilt locally, not committed). A heavy rebuild, so it is
   prompted rather than silent — corrections are often tiny and may not be worth a full
   re-index every time. A failure warns instead of aborting the sync.

> The **RAG / research corpus is NOT rebuilt here.** It comes from a *different
> source* (SuttaCentral `bilara-data`, not the tipitaka.lk canon), so it has its own
> sync source and its own script — see
> [sc-sync-ingest.md](./sc-sync-ingest.md).

### Step 7 — Write the provenance receipt (the missing piece)

The script writes a small JSON file, `scripts/bjt-sync-regen/bjt-provenance.json`,
recording **exactly what we synced**:

```json
{
  "source": "https://github.com/pathnirvana/tipitaka.lk.git",
  "branch": "master",
  "upstream_sha": "<new-sha>",
  "synced_on": "<ISO date>",
  "text_file_count": 285
}
```

This is what turns Step 0 into a one-line string compare forever after (the heartbeat
reads `upstream_sha` back out of this file). Without it we are back to guessing the
vintage of copy #3. It lives **beside the script**, not in `assets/` — the receipt is
tooling metadata, not canon content, and keeping it out lets `assets/` stay a faithful
1-to-1 mirror of tipitaka.lk. It is committed together with the assets on every sync.

---

## 5. What exists vs. what is TODO

| Piece | State |
|-------|-------|
| Read-only mirror at `tipitaka.lk-readonly` | ✅ Done (2026-07-23) |
| `scripts/bjt-sync-regen/sync-regen.sh` | ✅ Built (2026-07-23) |
| Heartbeat check (Step 0) | ✅ Done — `git ls-remote` vs receipt |
| Pull + review + copy (Steps 1–2, 4) | ✅ Done |
| `tree.json` guard (Step 3) | ✅ Done — separate, loud, blocks blind overwrite |
| Corpus verify (Step 5) | ✅ Done (2026-08-06) — `tools/check-dart-packages.sh`, warns on drift |
| Provenance receipt (Step 7) | ✅ Done — `scripts/bjt-sync-regen/bjt-provenance.json` |
| Static HTML rebuild (Step 6a) | 🔶 Stub — y/n prompt wired, generator not built |
| FTS rebuild (Step 6b) | ✅ Wired — y/n prompt runs `npm run generate-fts` |
| `--dry-run` / `--force` flags | ✅ Done |

---

## 6. Open questions

- **Automate or manual?** The heartbeat is cheap enough to schedule, but Steps 2–3
  (reviewing corrections + `tree.json`) want a human eye. Likely: automate the
  heartbeat + diff generation, keep the accept/copy step manual.
- **How to guard `tree.json`?** Decide what "a key moved" detection looks like —
  probably a nodeKey-level diff, not a line diff, so renames are caught explicitly.
- **Dictionary corrections?** The mirror's `db/dict.db` is skipped on disk (blobless
  fetches on demand), and dict is handled separately in the app. Out of scope here;
  revisit if dictionary updates are wanted too.
