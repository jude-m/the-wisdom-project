// Wire contract the Flutter app binds to — mirrors the Dart entities in
// lib/domain/entities/research/ and the retired Python server's §7 shapes.

export interface HistoryTurn {
  role: 'user' | 'assistant';
  content: string;
}

export interface Filters {
  basket?: string;
}

export interface ResearchRequest {
  question: string;
  history: HistoryTurn[];
  filters?: Filters;
  mode: 'fast' | 'thinking';
}

export interface Citation {
  uid: string;
  ref: string;
  title: string | null;
  kind: string;
  snippet: string | null;
}

export interface ResearchResponse {
  answer: string;
  lang: 'si' | 'en';
  citations: Citation[];
  /** Gemini model that generated the answer ("stub" for canned replies) —
   *  shown quietly in the UI for the curious. */
  model: string;
}

// Request caps — abuse ceilings, not mirrors of the client, which sends far
// less (ResearchChatState.maxUserTurns = 5 → ≤ 9 history turns; answers run
// ~5k chars). Sized with headroom so a client-side turn-cap bump doesn't
// break the server; raise these in step if that cap ever grows past 6.
// 4k UTF-16 code units ≈ 2k Sinhala graphemes (combining marks/ZWJ) — enough for a question as a start.
const QUESTION_MAX_CHARS = 4_000;
const HISTORY_MAX_TURNS = 12;
const TURN_MAX_CHARS = 8_000;

// The only basket values ingest ever writes (uid-derived — mirrors the Dart
// ResearchFilters contract). The value is spliced into Gemini's metadataFilter
// string, so free text must never pass; an unknown-but-harmless value would
// silently match nothing at retrieval, so reject loudly instead.
const BASKETS = new Set(['sutta', 'vinaya']);

export function parseRequest(body: unknown): ResearchRequest | null {
  if (typeof body !== 'object' || body === null) return null;
  const b = body as Record<string, unknown>;
  if (typeof b.question !== 'string' || b.question.length > QUESTION_MAX_CHARS) {
    return null;
  }

  const history: HistoryTurn[] = [];
  if (b.history !== undefined) {
    if (!Array.isArray(b.history) || b.history.length > HISTORY_MAX_TURNS) {
      return null;
    }
    for (const turn of b.history) {
      const t = turn as Record<string, unknown>;
      if (
        (t?.role !== 'user' && t?.role !== 'assistant') ||
        typeof t.content !== 'string' ||
        t.content.length > TURN_MAX_CHARS
      ) {
        return null;
      }
      history.push({ role: t.role, content: t.content });
    }
  }

  let filters: Filters | undefined;
  if (b.filters !== undefined && b.filters !== null) {
    const f = b.filters as Record<string, unknown>;
    if (typeof f !== 'object') return null;
    if (f.basket !== undefined && f.basket !== null) {
      if (typeof f.basket !== 'string' || !BASKETS.has(f.basket)) return null;
    }
    filters = { basket: (f.basket as string | undefined) ?? undefined };
  }

  const mode = b.mode ?? 'fast';
  if (mode !== 'fast' && mode !== 'thinking') return null;

  return { question: b.question, history, filters, mode };
}
