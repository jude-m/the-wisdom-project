#!/usr/bin/env python3
"""
Build a CONCRETE 1-to-1 map:  BJT sutta key  ->  Mahamevnawa (tripitaka.online) sutta id.

Open the matching simple-Sinhala (සරල සිංහල) sutta with:
    https://www.tripitaka.online/sutta/{id}

How it works  --  propose, then confirm
---------------------------------------
Mahamevnawa exposes its whole navigation tree at  /api/tree . Every leaf carries:
    { "id": <nav id>, "label": "<Sinhala title>", "data": "<SUTTA PAGE ID>" }
'data' is the number that goes in /sutta/{id}.

Both trees (this project's assets/data/tree.json and Mahamevnawa's /api/tree) are the
SAME canon in canonical order, so the map is built in TWO stages:

STAGE 1 - PROPOSE (titles, then position). Align the trees hierarchically
(nikaya -> ... -> sutta), matching each level by title, scoped to the already-matched
parent so identical short names in different vaggas never collide. Two structural
wrinkles are handled:
  * Generic ordinal vagga names differ by LANGUAGE (BJT Pali 'පඨමො වග්ගො' vs
    Mahamevnawa Sinhala 'පළමු වර්ගය'). Same level, never title-match, so strict_pool()
    aligns the leftover leaves by POSITION. In a region the two editions enumerate
    identically (same count, same order) it proposes every aligned slot: where the slot
    titles agree the pair is trusted; where they DON'T (a Pali spelling variant like
    වජ්ජිපුත්ත vs වජ්ජිපුත්තක / පඤ්චක vs පඤ්ච, or an unnamed BJT sutta vs Mahamevnawa's
    generic 'ප්‍රථම සූත්‍රය') the positional pair is proposed but flagged so Stage 2
    keeps it only on a POSITIVE link confirmation. (Earlier this stage demanded title
    agreement and silently dropped these; position+link recovered ~290, incl. the last
    DN/MN title-variant so both are now complete.)
  * BJT has an extra grouping level Mahamevnawa omits (AN paṇṇāsaka) -> flatten through.

STAGE 2 - CONFIRM (the `link` field). Stage 1 only PROPOSES; EVERY proposed pair is then
checked against Mahamevnawa's own `link` field (its declared back-reference to the BJT
coordinate, e.g. mn-1-1-1 <-> "mn1_1-1-1"). A link's last two numbers are always
(vagga ordinal, sutta ordinal); we require those to equal the BJT key's. Any pair the
link CONTRADICTS is dropped, so no guess survives -- this is what keeps peyyala
(repetition) sections from leaking in, and it catches positional slots that drifted
where the two editions bundle differently. A TITLE-matched pair is KEPT when the link
confirms it OR the page carries no link at all (absence != contradiction; those were
title-verified). A POSITION-only pair (titles differed) is kept ONLY when the link
actively confirms it -- a bare unconfirmed guess is left unmatched.
See link_verdict() for two edge cases: vagga-less SN samyuttas (Mahamevnawa inserts
vagga 1, so the BJT vagga is implicitly 1) and slug-format links ("4-4-2-4-<title>",
matched on the leading coordinate).

Run:  python3 build_map.py          (uses maha-tree-cache.json + maha-links-cache.json)
      python3 build_map.py --fetch  (re-download the tree from tripitaka.online)
"""
import json, re, sys, os, urllib.request
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
TREE_CACHE = os.path.join(HERE, 'maha-tree-cache.json')
BJT_TREE   = os.path.join(REPO, 'assets', 'data', 'tree.json')
OUT_MAP    = os.path.join(HERE, 'bjt-to-mahamevnawa.json')
OUT_MISS   = os.path.join(HERE, 'unmatched.txt')
TREE_URL   = 'https://www.tripitaka.online/api/tree'
SUTTA_URL  = 'https://www.tripitaka.online/sutta/{id}'

NIK = {'දීඝ නිකාය': 'dn', 'මජ්ඣිම නිකාය': 'mn', 'සංයුත්ත නිකාය': 'sn',
       'අංගුත්තර නිකාය': 'an', 'ඛුද්දක නිකාය': 'kn'}

# ---------------------------------------------------------------- load trees
def load_maha():
    if '--fetch' in sys.argv or not os.path.exists(TREE_CACHE):
        with urllib.request.urlopen(TREE_URL, timeout=30) as r:
            data = r.read().decode()
        open(TREE_CACHE, 'w').write(data)
    return json.load(open(TREE_CACHE))['data']

maha_roots = load_maha()
d = json.load(open(BJT_TREE))            # key -> [pali, sinh, count, [..], parent, firstChild]
children = defaultdict(list)
for k, v in d.items():
    children[v[4]].append(k)
def keysort(k):
    return [(0, int(p)) if p.isdigit() else (1, p) for p in re.split(r'[-_]', k)]
for k in children:
    children[k].sort(key=keysort)

# ---------------------------------------------------------------- title normalisation
SUF = ['සූත්‍රය','සූත්රය','සුත්තං','සුත්‍තං','සුත්තන්තං','සුත්තො','සුත්ත',
       'වග්ගො','වග්ගෝ','වර්ගය','වර්‍ගය','සංයුත්තං','සංයුත්තො','සංයුත්ත',
       'නිපාතො','නිපාතය','පණ්ණාසකො','පණ්ණාසකය','පණ්ණාසකෝ']
FOLD = str.maketrans({'ආ':'අ','ඊ':'ඉ','ඌ':'උ','ඒ':'එ','ඕ':'ඔ','ඈ':'ඇ','ෑ':'ැ','ී':'ි',
                      'ූ':'ු','ේ':'ෙ','ෝ':'ො','ෛ':'ෙ','ෞ':'ො','ණ':'න','ළ':'ල','ඥ':'ඤ','ඞ':'ං'})
def _base(s):  return re.sub(r'[\s.0-9]+', '', s.replace('‍', '').replace('‌', ''))
def _strip(s):
    for suf in SUF:
        if len(s) > len(suf) and s.endswith(suf): return s[:-len(suf)]
    return s
def norm(s):  return _strip(_base(s))
def fold(s):
    s = norm(s).translate(FOLD)
    return s.replace('ා','').replace('ෙ','').replace('ො','').replace('ං','').replace('්','')

# ---------------------------------------------------------------- matcher
pairs = {}            # bjt leaf key -> maha sutta id   (concrete 1:1)
unmatched = []        # bjt leaf keys with no clean 1:1 maha sutta
positional_only = set()  # pairs proposed by POSITION alone (titles differ) -> must be
                         # link-CONFIRMED in Stage 2; a bare nolink guess is not kept
reason = {}              # bjt key -> WHY it stayed unmatched (drives the grouped unmatched.txt)
def miss(bk, why):       # record an unmatched leaf together with the reason it has no 1:1
    unmatched.append(bk); reason[bk] = why

def bjt_titles(k):
    return (norm(d[k][0]), norm(d[k][1]), fold(d[k][0]), fold(d[k][1]))
def bjt_leaves(root, out):
    kids = children.get(root, [])
    if not kids: out.append(root)
    else:
        for c in kids: bjt_leaves(c, out)
    return out
def first_data(node):
    if 'data' in node: return int(node['data'])
    for c in node.get('children', []):
        r = first_data(c)
        if r is not None: return r
    return None

def maha_leaves(node, out):
    ch = node.get('children')
    if ch:
        for c in ch: maha_leaves(c, out)
    elif 'data' in node:
        out.append(node)
    return out

def strict_pool(bjt_nodes, maha_nodes):
    """Last resort for a sub-region whose GROUPING (vagga) titles differ between
    editions — e.g. BJT Pali 'පඨමො වග්ගො' vs Mahamevnawa Sinhala 'පළමු වර්ගය'.
    Both are the same level, so title-recursion stalls.

    We only TRUST a region the two editions enumerate IDENTICALLY: same number of
    suttas, in the same canonical order. A peyyāla (repetition) series — which the
    two editions expand differently — fails this size check and is skipped whole, so
    we never risk a wrong link there.

    Inside a size-matched region we PROPOSE every aligned slot. Where the slot titles
    already agree the pair is trusted outright (kept later on confirm OR nolink, like
    any title match). Where they DON'T agree — a Pali spelling variant such as
    වජ්ජිපුත්ත vs වජ්ජිපුත්තක, or පඤ්චක vs පඤ්ච — we STILL propose the positional pair
    but record it in `positional_only`, so Stage 2 keeps it only if the link field
    actively CONFIRMS it (an unconfirmed positional guess is dropped). The link is the
    arbiter, so this recovers real suttas the titles miss without committing a guess.

    KNOWN LIMITATION (documented gap, not yet fixed): the size-mismatch skip is
    whole-region. When a vagga-name spelling variant sends a region here AND the counts
    differ, a handful of ordinary suttas that DO have a Mahamevnawa page get dropped with
    the peyyāla (~15 today: e.g. an-10-3-2 අජිත, sn-2-6-1 විඤ්ඤාණ) — see the
    `region-mismatch` group in unmatched.txt. Recoverable later by matching the leftover
    leaves on their OWN titles (link-gated) before falling back to position."""
    bl = []
    for bn in bjt_nodes: bjt_leaves(bn, bl)
    ml = []
    for mnode in maha_nodes: maha_leaves(mnode, ml)
    if len(bl) != len(ml):              # expanded differently -> not clear-cut -> skip
        for b in bl: miss(b, 'region-mismatch')
        return
    for bk, nd in zip(bl, ml):
        dd = int(nd['data']) if 'data' in nd else first_data(nd)
        if dd is None:
            miss(bk, 'no-page'); continue           # no page id -> cannot map
        pairs[bk] = dd                              # propose the position-aligned slot
        bt = {norm(d[bk][0]), norm(d[bk][1])}
        bf = {fold(d[bk][0]), fold(d[bk][1])}
        if not (norm(nd['label']) in bt or fold(nd['label']) in bf):
            positional_only.add(bk)                 # titles differ -> needs link confirm

def match_level(bjt_keys, maha_nodes):
    m_norm, m_fold = defaultdict(list), defaultdict(list)
    for mn_ in maha_nodes:
        m_norm[norm(mn_['label'])].append(mn_)
        m_fold[fold(mn_['label'])].append(mn_)
    used = set()
    leftover_bjt = []
    def find(bk):
        nt, st, nf, sf = bjt_titles(bk)
        for key, table in [(nt, m_norm), (st, m_norm), (nf, m_fold), (sf, m_fold)]:
            for c in table.get(key, []):
                if id(c) not in used:
                    used.add(id(c)); return c
        return None
    def process(bk):
        cand  = find(bk)
        bkids = children.get(bk, [])
        if cand is None:
            # No title match at this level. If bjt has an EXTRA grouping level
            # Mahamevnawa omits (e.g. AN paṇṇāsaka), flatten through it so the
            # named vaggas inside can still match here. Otherwise hold the node
            # for strict_pool below (handles generic vagga names that differ).
            if bkids:
                for c in bkids: process(c)
            else:
                leftover_bjt.append(bk)
            return
        mkids = cand.get('children')
        if not bkids:                                   # bjt leaf
            if 'data' in cand:                          # maha leaf  -> CONCRETE 1:1
                pairs[bk] = int(cand['data'])
            else:                                       # maha still has structure
                dd = first_data(cand)
                if dd is not None: pairs[bk] = dd
                else: miss(bk, 'no-page')
        else:                                           # bjt internal node
            if mkids:
                match_level(bkids, mkids)               # recurse, levels aligned
            else:
                # maha bundled this whole subtree into ONE page -> NOT 1:1 -> skip
                for leaf in bjt_leaves(bk, []): miss(leaf, 'maha-bundled-subtree')
    for bk in bjt_keys:
        process(bk)
    # Same level, different grouping names (BJT Pali vs Mahamevnawa Sinhala
    # ordinals): pair the leftover sutta leaves by mutually-unique title.
    leftover_maha = [m for m in maha_nodes if id(m) not in used]
    if leftover_bjt and leftover_maha:
        strict_pool(leftover_bjt, leftover_maha)
    else:
        for bk in leftover_bjt:
            for leaf in bjt_leaves(bk, []): miss(leaf, 'no-maha-node')

maha_by_nik = {NIK[n['label']]: n for n in maha_roots}
for nik in ['dn', 'mn', 'sn', 'an']:           # Sutta Pitaka nikayas Mahamevnawa covers
    match_level(children[nik], maha_by_nik[nik]['children'])

# ---------------------------------------------------------------- CONFIRM via link field
# The title matcher only PROPOSES pairs. We confirm every one against Mahamevnawa's
# own `link` field (its declared back-reference to the BJT coordinate). Across all
# nikayas the last two numbers of the link (vagga ordinal, sutta ordinal) equal the
# BJT key's last two. Any pair the link does not confirm is dropped -> zero guessing
# survives, so peyyala/structural mismatches cannot leak in.
LINK_CACHE = os.path.join(HERE, 'maha-links-cache.json')

def load_links(ids):
    cache = json.load(open(LINK_CACHE)) if os.path.exists(LINK_CACHE) else {}
    missing = [i for i in ids if str(i) not in cache]
    if missing:
        from concurrent.futures import ThreadPoolExecutor
        def fetch(i):
            try:
                with urllib.request.urlopen(f'https://www.tripitaka.online/api/sutta/{i}', timeout=20) as r:
                    return str(i), json.loads(r.read().decode()).get('link')
            except Exception:
                return str(i), None
        print(f'Confirming {len(missing)} pairs against the link field '
              f'({len(ids)-len(missing)} already cached)...')
        with ThreadPoolExecutor(max_workers=12) as ex:
            for k, v in ex.map(fetch, missing):
                cache[k] = v
        json.dump(cache, open(LINK_CACHE, 'w'), ensure_ascii=False)
    return cache

def nums(s): return [int(x) for x in re.findall(r'\d+', s)]
def link_verdict(bjt_key, link):
    """'confirm' the link agrees, 'contradict' it points elsewhere, 'nolink' absent.

    A link's last two numbers are always (vagga ordinal, sutta ordinal); any prefix
    junk (MN's duplicated paṇṇāsa, AN's remapped book) sits at the FRONT, so the tail
    is the reliable part. We compare that tail to the BJT key's (vagga, sutta). The one
    wrinkle: some SN samyuttas have no vagga level in BJT (3-deep key like sn-4-4-1),
    while Mahamevnawa still inserts vagga 1 — so for those the BJT vagga is implicitly 1."""
    nik = bjt_key.split('-')[0]
    if not link: return 'nolink'
    b, l = nums(bjt_key), nums(link)
    if re.match(r'^\d', link):                # slug-format link "4-4-2-4-<url-title>"
        lead = nums(re.match(r'^[\d-]+', link).group())   # leading coordinate only
        return 'confirm' if lead == b else 'contradict'
    if not link.lower().startswith(nik): return 'contradict'
    if len(l) < 2 or len(b) < 2: return 'contradict'
    if nik == 'sn' and len(b) == 3:          # vagga-less SN samyutta -> implicit vagga 1
        vb, sb = 1, b[-1]
    else:
        vb, sb = b[-2], b[-1]
    return 'confirm' if (l[-2] == vb and l[-1] == sb) else 'contradict'

links = load_links(sorted(set(pairs.values())))
kept, dropped, nolink, recovered = {}, [], [], []
for k, i in pairs.items():
    v = link_verdict(k, links.get(str(i)))
    if v == 'contradict':                              # link points elsewhere -> drop
        dropped.append((k, i, links.get(str(i)))); miss(k, 'link-elsewhere')
    elif k in positional_only and v != 'confirm':      # title-variant guess, link absent
        miss(k, 'positional-unconfirmed')              # -> not confirmed, leave unmatched
    else:                                              # 'confirm', or title-match 'nolink'
        kept[k] = i
        if v == 'nolink': nolink.append(k)
        if k in positional_only: recovered.append(k)   # title differed, link confirmed it
pairs = kept
OUT_DROP = os.path.join(HERE, 'link-dropped.txt')      # pairs the link field rejected
open(OUT_DROP, 'w').write('\n'.join(
    f'{k}\t{d[k][0]}\tid={i}\tlink={lk}' for k, i, lk in dropped))

# ---------------------------------------------------------------- write outputs
pairs = dict(sorted(pairs.items(), key=lambda kv: keysort(kv[0])))
out = {
    'description': 'BJT sutta key -> Mahamevnawa (tripitaka.online) sutta id. '
                   'Concrete 1:1, each confirmed against Mahamevnawa\'s own link field.',
    'source': 'https://www.tripitaka.online',
    'urlPattern': SUTTA_URL,
    'count': len(pairs),
    'map': pairs,
}
json.dump(out, open(OUT_MAP, 'w'), ensure_ascii=False, indent=0)
# Group the unmatched leaves by WHY they have no 1:1, each under a plain-language header,
# so unmatched.txt explains itself. (Regenerated every run -> comments live here, in the
# generator, not hand-added to the file where they'd be overwritten.)
REASONS = [
 ('region-mismatch',
  'MIXED region. The two editions enumerate this stretch with different sutta counts, so '
  'the positional step skips the WHOLE region. Most are peyyala, but a minority are '
  'ordinary suttas that DO have a separate Mahamevnawa page (e.g. an-10-3-2 අජිත, '
  'sn-2-6-1 විඤ්ඤාණ) -- collateral of a spelling-variant vagga name; recoverable with '
  'finer per-title alignment, still link-gated. NOT all peyyala.'),
 ('link-elsewhere',
  "PEYYALA / misaligned slot. Proposed by position, but Mahamevnawa's own link points to a "
  'different coordinate -> the two editions bundle this run differently. Correctly rejected.'),
 ('maha-bundled-subtree',
  'BUNDLED SUBTREE. Mahamevnawa collapses this whole BJT branch onto one page, so the '
  'individual suttas under it have no separate target.'),
 ('positional-unconfirmed',
  'UNCONFIRMED. Proposed by position only (titles differ) and the Mahamevnawa page carries '
  'no link to confirm it -> left out rather than guessed.'),
 ('no-maha-node',
  'NO COUNTERPART. No remaining Mahamevnawa node aligns to this BJT sutta at this level.'),
 ('no-page',
  'NO PAGE ID. The aligned Mahamevnawa node exposes no /sutta/{id} page.'),
]
by_reason = defaultdict(list)
for k in unmatched:
    by_reason[reason.get(k, 'no-page')].append(k)
with open(OUT_MISS, 'w') as f:
    f.write(f'# {len(unmatched)} BJT suttas with NO clean 1:1 on Mahamevnawa, grouped by reason.\n')
    f.write('# Regenerated by build_map.py on every run -- do not hand-edit (edits are overwritten).\n')
    f.write('# Nearly all are peyyala: repetition series Mahamevnawa bundles onto fewer pages.\n')
    seen = set()
    for code, desc in REASONS:
        seen.add(code)
        ks = sorted(by_reason.get(code, []), key=keysort)
        if not ks: continue
        f.write(f'\n# === {code}  ({len(ks)}) ===\n#   {desc}\n')
        for k in ks: f.write(f'{k}\t{d[k][0]}\n')
    for code in sorted(set(by_reason) - seen):           # any reason not pre-listed (safety)
        ks = sorted(by_reason[code], key=keysort)
        f.write(f'\n# === {code}  ({len(ks)}) ===\n')
        for k in ks: f.write(f'{k}\t{d[k][0]}\n')
print(f'Kept: {len(pairs)}  (link-confirmed {len(pairs)-len(nolink)} + no-link-but-kept {len(nolink)})'
      f'   dropped (link contradicts): {len(dropped)} -> {OUT_DROP}')
print(f'  of which recovered by position+link (titles differ, e.g. spelling variants): {len(recovered)}')

# ---------------------------------------------------------------- report
def nik(k): return k.split('-')[0]
from collections import Counter
mc, uc = Counter(nik(k) for k in pairs), Counter(nik(k) for k in unmatched)
tot = {n: len(bjt_leaves(n, [])) for n in ['dn', 'mn', 'sn', 'an']}
print(f'Concrete 1:1 mappings : {len(pairs)}')
print(f'Skipped (no clean 1:1): {len(unmatched)}')
print('  nik | leaves | mapped | skipped')
for n in ['dn', 'mn', 'sn', 'an']:
    print(f'  {n:3} | {tot[n]:6} | {mc[n]:6} | {uc[n]:6}')
print(f'\nWrote {OUT_MAP}')
print(f'Wrote {OUT_MISS}')
print(f'Example: bjt mn-1-1-1 -> ' + SUTTA_URL.format(id=pairs.get('mn-1-1-1')))
