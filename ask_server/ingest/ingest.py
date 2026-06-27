#!/usr/bin/env python3
"""Ingest both bilara-data trees into a Gemini File Search store (design §8).

One document per text unit (a sutta, or a Vinaya rule/section). display_name = the
uid (it rides into every citation as the chunk title). custom_metadata is DERIVED
from the uid — never hand-annotated onto the JSON (design §5.2).

Idempotent + resumable: uids already in the store are skipped, so a re-run after a
failure picks up where it stopped.

Usage:
    # Validate discovery + metadata WITHOUT a key or any upload:
    python -m ingest.ingest --dry-run --limit 5

    # Real run (needs GEMINI_API_KEY; creates the store if --store omitted):
    python -m ingest.ingest --store fileSearchStores/tipitaka-en-xxxx
    python -m ingest.ingest                 # creates a fresh store, prints its name

Point --bilara-dir (or BILARA_DATA_DIR) at a local checkout of
github.com/suttacentral/bilara-data (the `published` branch).
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys
import tempfile
import time

# Suttas (Sujato) + Vinaya (Brahmali) — the two CC0 trees (design §5.2). The
# Vinaya tree is NOT optional: money/monastic-rule questions need it.
GLOBS = (
    "translation/en/sujato/sutta/**/*-sujato.json",
    "translation/en/brahmali/vinaya/**/*-brahmali.json",
)


def meta_from_uid(uid: str) -> dict:
    """Basket + sub-fields, deterministically from the uid prefix (design §5.2)."""
    if uid.startswith("pli-tv-"):
        division = (
            "bhikkhuni" if "-bi-" in uid else "bhikkhu" if "-bu-" in uid else None
        )
        md = {"basket": "vinaya"}
        if division:
            md["division"] = division
        return md
    m = re.match(r"[a-z]+", uid)
    return {"basket": "sutta", "nikaya": m.group() if m else ""}


def load_unit(path: str) -> tuple[str, str] | None:
    """Read one bilara JSON file → (uid, document_text). None if empty.

    Document text = heading segments (`uid:0.*`) + body (the rest, in order), as
    clean prose with no inline ids — clean text embeds better (design §8).
    """
    with open(path, encoding="utf-8") as f:
        segs = json.load(f)
    if not segs:
        return None
    uid = next(iter(segs)).split(":")[0]
    head = " ".join(segs[k].strip() for k in segs if k.startswith(f"{uid}:0."))
    body = " ".join(
        segs[k].strip()
        for k in segs
        if not k.startswith(f"{uid}:0.") and segs[k].strip()
    )
    text = f"{head}\n{body}".strip()
    return (uid, text) if text else None


def discover(bilara_dir: str) -> list[str]:
    paths: list[str] = []
    for pattern in GLOBS:
        paths.extend(glob.glob(os.path.join(bilara_dir, pattern), recursive=True))
    return sorted(paths)


def run(args: argparse.Namespace) -> int:
    bilara_dir = args.bilara_dir
    if not os.path.isdir(bilara_dir):
        print(f"error: bilara-data dir not found: {bilara_dir}", file=sys.stderr)
        print(
            "Clone github.com/suttacentral/bilara-data (published branch) and "
            "point --bilara-dir / BILARA_DATA_DIR at it.",
            file=sys.stderr,
        )
        return 2

    paths = discover(bilara_dir)
    if args.limit:
        paths = paths[: args.limit]
    print(f"discovered {len(paths)} unit files under {bilara_dir}")

    if args.dry_run:
        for path in paths:
            unit = load_unit(path)
            if not unit:
                print(f"  (empty) {path}")
                continue
            uid, text = unit
            preview = text[:80].replace("\n", " ")
            print(f"  {uid:24} {meta_from_uid(uid)}  «{preview}…»")
        print("dry-run only — nothing uploaded.")
        return 0

    # ---- live upload ----
    from google import genai  # lazy: dry-run needs no SDK

    client = genai.Client()
    store_name = args.store
    if not store_name:
        store = client.file_search_stores.create(
            config={"display_name": args.display_name}
        )
        store_name = store.name
        print(f"created store: {store_name}")
    else:
        print(f"using store: {store_name}")

    existing = _existing_uids(client, store_name)
    print(f"{len(existing)} uids already in store — will skip those")

    uploaded = skipped = failed = 0
    for path in paths:
        unit = load_unit(path)
        if not unit:
            continue
        uid, text = unit
        if uid in existing:
            skipped += 1
            continue
        try:
            _upload(client, store_name, uid, text, meta_from_uid(uid))
            uploaded += 1
        except Exception as exc:  # noqa: BLE001 — keep going, log, back off
            failed += 1
            print(f"  ! failed {uid}: {exc}", file=sys.stderr)
            time.sleep(args.backoff)

    print(f"done: {uploaded} uploaded, {skipped} skipped, {failed} failed")
    print(f"\nSet ASK_STORE={store_name} in the service environment.")
    return 0 if failed == 0 else 1


def _existing_uids(client, store_name: str) -> set[str]:
    """display_names (= uids) already in the store, for resumable runs.

    The list API shape can differ by SDK version (Appendix A); on any error we
    simply don't skip — at worst a re-run re-uploads, which the store dedupes by
    display_name.
    """
    uids: set[str] = set()
    try:
        for doc in client.file_search_stores.documents.list(parent=store_name):
            name = getattr(doc, "display_name", None)
            if name:
                uids.add(name)
    except Exception as exc:  # noqa: BLE001
        print(f"  (could not list existing docs; not skipping: {exc})",
              file=sys.stderr)
    return uids


def _upload(client, store_name: str, uid: str, text: str, md: dict) -> None:
    with tempfile.NamedTemporaryFile(
        "w", suffix=f"_{uid}.txt", delete=False, encoding="utf-8"
    ) as f:
        f.write(text)
        tmp = f.name
    try:
        client.file_search_stores.upload_to_file_search_store(
            file_search_store_name=store_name,
            file=tmp,
            config={
                "display_name": uid,
                "custom_metadata": [
                    {"key": k, "string_value": v} for k, v in md.items()
                ],
            },
        )
    finally:
        os.unlink(tmp)


def main() -> int:
    ap = argparse.ArgumentParser(description="Ingest bilara-data → File Search.")
    ap.add_argument(
        "--bilara-dir",
        default=os.environ.get("BILARA_DATA_DIR", "../bilara-data"),
    )
    ap.add_argument(
        "--store",
        default=os.environ.get("ASK_STORE"),
        help="existing store resource name; omit to create a new one",
    )
    ap.add_argument(
        "--display-name",
        default="tipitaka-en",
        help="display name for a newly created store",
    )
    ap.add_argument(
        "--dry-run",
        action="store_true",
        help="discover + derive metadata only; no SDK, no upload",
    )
    ap.add_argument(
        "--limit", type=int, default=0, help="process at most N files (0 = all)"
    )
    ap.add_argument(
        "--backoff",
        type=float,
        default=1.0,
        help="seconds to sleep after a failed upload",
    )
    return run(ap.parse_args())


if __name__ == "__main__":
    raise SystemExit(main())
