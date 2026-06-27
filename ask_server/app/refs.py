"""Canonical-reference helpers (pure, no network).

Two directions, used by the citation builder (design §5.5):
  uid → ref    "sn15.3"  → "SN 15.3"   (display form rides into citations)
  ref → uid    "SN 15.3" → "sn15.3"    (linkify refs named in answer prose)

`known_uid` decides whether a ref named in the answer actually exists, so we drop
hallucinated references instead of minting dead links (design §11.9). It consults
an optional manifest file (ASK_UID_MANIFEST: one uid per line — emit it from the
ingest job); with no manifest it falls back to a permissive shape check.

NOTE: this is canonical-*reference* parsing (uid <-> display ref). It is distinct
from the SuttaCentral->BJT *resolver* (resolver plan Part B) that maps a uid to an
in-app node key. That resolver lives in packages/wisdom_shared and lands later.
"""
from __future__ import annotations

import os
import re
from functools import lru_cache

# The abbreviations the design's linkifier recognises (§5.5).
NIKAYAS = (
    "SN", "MN", "DN", "AN", "KN", "Snp", "Dhp", "Ud", "Iti", "Thag", "Thig",
)

# Matches a canonical ref inside answer prose: "SN 15.3", "Dhp155", "MN 10".
REF_IN_PROSE = re.compile(r"\b(" + "|".join(NIKAYAS) + r")\s?\d+(?:\.\d+)?\b")

# A sutta uid: leading letters (the nikaya) then a number, e.g. "sn15.3".
_UID_SUTTA = re.compile(r"^([a-z]+)(\d.*)$")


def ref_from_uid(uid: str) -> str:
    """uid → human display ref. Vinaya uids are kept verbatim (no short form)."""
    if uid.startswith("pli-tv-"):
        return uid
    m = _UID_SUTTA.match(uid)
    if not m:
        return uid
    return f"{m.group(1).upper()} {m.group(2)}"


def uid_from_ref(ref: str) -> str | None:
    """Display ref → uid. "SN 15.3" → "sn15.3". None if it isn't a ref."""
    s = ref.strip().lower().replace(" ", "")
    return s if re.match(r"^[a-z]+\d", s) else None


@lru_cache(maxsize=1)
def _manifest() -> frozenset[str] | None:
    path = os.environ.get("ASK_UID_MANIFEST")
    if not path or not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as f:
        return frozenset(line.strip() for line in f if line.strip())


def known_uid(uid: str) -> bool:
    """True if `uid` is a real corpus id. Manifest if present, else shape check."""
    manifest = _manifest()
    if manifest is not None:
        return uid in manifest
    # No manifest (prototype): accept anything that parses as a canonical uid.
    return bool(_UID_SUTTA.match(uid)) or uid.startswith("pli-tv-")
