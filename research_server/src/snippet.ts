// Snippet building is the CPU hotspot (Python worst case: 27ms). Budget levers
// used here: the body is truncated to a scan bound BEFORE any normalization,
// folded once per body with native string ops (no per-word regex walk), and
// terms are located with indexOf — a body with no term hit costs three native
// passes and nothing more. Callers dedupe by uid first, so all of this runs
// once per displayed source, not once per retrieved chunk.
//
// Kill switch if the 10ms budget is ever threatened: rung 1 — snippet only the
// uids that got a [[cite:]] chip (reorder buildResponse: finalize answer text
// first, then snippet the chipped set — typically 2–5 of ~14 sources; if zero
// chips, keep all so the cards aren't stripped bare). Rung 2 — skip makeSnippet
// entirely. `snippet: null` is contract-legal (prose-only cards already ship
// it) and rung-2 worst-case CPU is ~1–2ms.

const STOPWORDS = new Set(
  ('and are but for from how its not that the their them then there these they ' +
    'this was were what when where which who why will with you your').split(' '),
);

const WORD = /[\p{L}\p{M}]+/gu;
const MARKS = /\p{M}+/gu;
const WS = /\s+/g;
const LETTER = /\p{L}/u;

const SNAP = 24;
const ELLIPSIS_RESERVE = 4;
const MAX_SCAN_CHARS = 12_000;
const MAX_MATCHES = 24;
const MAX_MATCHES_PER_TERM = 8;
const FOLD_CACHE_MAX = 20_000;

// Fold = lowercase + strip diacritics ("Sāvatthī" → "savatthi"). The cache
// serves query terms and window words; whole bodies use foldText directly.
const foldCache = new Map<string, string>();

const foldText = (s: string): string =>
  s.toLowerCase().normalize('NFKD').replace(MARKS, '');

export function fold(word: string): string {
  let f = foldCache.get(word);
  if (f === undefined) {
    f = foldText(word);
    if (foldCache.size >= FOLD_CACHE_MAX) foldCache.clear();
    foldCache.set(word, f);
  }
  return f;
}

export function queryTerms(query: string): Set<string> {
  const terms = new Set<string>();
  for (const m of (query || '').matchAll(WORD)) {
    const folded = fold(m[0]);
    if (folded.length > 2 && !STOPWORDS.has(folded)) terms.add(folded);
  }
  return terms;
}

interface Match {
  start: number;
  end: number;
  term: string;
}

// indexOf per term over the folded body, word-boundary checked. Folded offsets
// drift from the original only where marks were stripped (sparse in this
// corpus); the window's word-snapping absorbs that.
function findTermMatches(folded: string, terms: Set<string>): Match[] {
  const out: Match[] = [];
  for (const term of terms) {
    let from = 0;
    let found = 0;
    while (found < MAX_MATCHES_PER_TERM) {
      const idx = folded.indexOf(term, from);
      if (idx === -1) break;
      const end = idx + term.length;
      const before = idx > 0 ? folded[idx - 1]! : '';
      const after = end < folded.length ? folded[end]! : '';
      if (!LETTER.test(before) && !LETTER.test(after)) {
        out.push({ start: idx, end, term });
        found++;
      }
      from = end;
    }
  }
  out.sort((a, b) => a.start - b.start);
  return out.length > MAX_MATCHES ? out.slice(0, MAX_MATCHES) : out;
}

export function makeSnippet(text: string, terms: Set<string>, maxChars = 220): string {
  // Bound the body first; whitespace-normalize only the emitted window (ingest
  // joins segments with single spaces, so a body-wide pass is wasted work).
  text = (text || '').slice(0, MAX_SCAN_CHARS).trim();
  if (!text) return '';
  if (text.length <= maxChars) return boldTerms(text.replace(WS, ' '), terms);

  const budget = Math.max(1, maxChars - ELLIPSIS_RESERVE);
  if (!terms.size) return head(text, budget);

  const matches = findTermMatches(foldText(text), terms);
  if (!matches.length) return head(text, budget);

  // Densest cluster: the match whose following budget-window covers the most
  // distinct terms wins; earliest wins ties.
  let bestI = 0;
  let bestScore = 0;
  for (let i = 0; i < matches.length; i++) {
    const limit = matches[i]!.start + budget;
    const seen = new Set<string>();
    for (let j = i; j < matches.length && matches[j]!.end <= limit; j++) {
      seen.add(matches[j]!.term);
    }
    if (seen.size > bestScore) {
      bestScore = seen.size;
      bestI = i;
    }
  }

  // Forward-biased window around the cluster, snapped to word boundaries.
  let start = Math.max(0, matches[bestI]!.start - Math.floor(budget / 3));
  let end = Math.min(text.length, start + budget);
  start = Math.max(0, end - budget);
  if (start > 0) {
    const sp = text.indexOf(' ', start);
    if (sp !== -1 && sp - start <= SNAP) start = sp + 1;
  }
  if (end < text.length) {
    const sp = text.lastIndexOf(' ', end);
    if (sp !== -1 && end - sp <= SNAP) end = sp;
  }
  const window = text.slice(start, end).replace(WS, ' ').trim();
  return boldTerms(wrap(window, start > 0, end < text.length), terms);
}

// Split a chunk at the ingest "<heading>\n<body>" boundary. Only a head chunk
// whose first line carries the ref number is a heading; the number itself is
// dropped from the title (the citation already shows it as `ref`).
export function splitHeading(
  text: string,
  ref?: string | null,
): { title: string | null; body: string } {
  const nl = text.indexOf('\n');
  const num = refNumber(ref);
  if (nl === -1 || !num) return { title: null, body: text };
  const headLine = text.slice(0, nl);
  const numRe = new RegExp(`\\b${escapeRe(num)}\\b`);
  if (!numRe.test(headLine)) return { title: null, body: text };
  const title = headLine
    .trim()
    .replace(new RegExp(`^(.{0,40}?)\\b${escapeRe(num)}\\b[\\s.,:–—-]*`), '$1')
    .replace(WS, ' ')
    .trim();
  return { title: title || null, body: text.slice(nl + 1) };
}

function refNumber(ref?: string | null): string | null {
  const m = /\d+(?:[.\-]\d+)*/.exec(ref ?? '');
  return m ? m[0] : null;
}

const escapeRe = (s: string): string => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

function boldTerms(window: string, terms: Set<string>): string {
  if (!terms.size) return window;
  const spans: [number, number][] = [];
  for (const m of window.matchAll(WORD)) {
    if (terms.has(fold(m[0]))) {
      spans.push([m.index, m.index + m[0].length]);
    }
  }
  for (let i = spans.length - 1; i >= 0; i--) {
    const [s, e] = spans[i]!;
    window = `${window.slice(0, s)}**${window.slice(s, e)}**${window.slice(e)}`;
  }
  return window;
}

function head(text: string, maxChars: number): string {
  const cut = text.lastIndexOf(' ', maxChars);
  return wrap(text.slice(0, cut > 0 ? cut : maxChars).replace(WS, ' '), false, true);
}

function wrap(window: string, left: boolean, right: boolean): string {
  window = window.trim();
  if (left) window = `… ${window}`;
  if (right) window = `${window.replace(/[.,;:— ]+$/, '')} …`;
  return window;
}
