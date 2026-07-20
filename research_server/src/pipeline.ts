// The live /research pipeline: detect → rewrite/translate → generate with the
// File Search tool → citations. buildResponse is pure (no I/O) so the CPU-side
// post-processing can be benchmarked standalone.

import {
  Config,
  deadlineForMode,
  modelsForMode,
  THINKING_BUDGET_TOKENS,
  THINKING_LEVEL,
} from './config.js';
import { Citation, ResearchRequest, ResearchResponse } from './contracts.js';
import { EmptyAnswerError, MSG, ResearchError } from './errors.js';
import {
  callWithLadder,
  generateContent,
  GenerateResponse,
  responseText,
} from './gemini.js';
import { isSinhala } from './lang.js';
import { knownUid, REF_IN_PROSE, refFromUid, uidFromRef } from './refs.js';
import { makeSnippet, queryTerms, splitHeading } from './snippet.js';
import { cpuMs } from './timing.js';

const GLOSSARY = 'saṁsāra→සංසාරය; transmigration→සංසරණය; charnel ground→සොහොන් බිම';

const SYSTEM =
  'Answer questions about the Pali Canon using ONLY the retrieved passages.\n' +
  'Cite the text by standard reference (e.g. SN 15.3) for every claim.\n' +
  "If the passages don't contain the answer, say so. Never invent a reference.\n" +
  'If coverage may be partial, say so. For disputed meanings, present the range ' +
  'of readings rather than a verdict.\n' +
  'Format with simple Markdown only: short paragraphs, **bold**, *italic*, and ' +
  "'- ' bullets. Do not use headings, tables, or nested lists.\n" +
  'Answer in {lang}.{glossary}';

const cite = (uid: string): string => `[[cite:${uid}]]`;

const systemInstruction = (isSi: boolean): string =>
  SYSTEM.replace('{lang}', isSi ? 'Sinhala' : 'English').replace(
    '{glossary}',
    isSi ? `\nPrefer these Sinhala renderings: ${GLOSSARY}` : '',
  );

export interface AnswerMeta {
  model: string;
  rung: number;
  buildCpuMs: number | null;
  /** Size of Gemini's answer-call payload in chars — the live CPU driver. */
  bodyChars: number | null;
}

export async function answer(
  cfg: Config,
  req: ResearchRequest,
  reqId: string,
): Promise<{ response: ResearchResponse; meta: AnswerMeta }> {
  if (!cfg.store || !cfg.apiKey) {
    throw new ResearchError(503, 'service_unavailable', MSG.serviceBusy, true);
  }
  const isSi = isSinhala(req.question);
  // One deadline for the whole request (rewrite + generate share it), matching
  // the client's single HTTP timeout for the round trip.
  const deadline = Date.now() + deadlineForMode(req.mode);

  const searchQ = await rewrite(cfg, req, isSi, reqId, deadline);
  const basket = req.filters?.basket;

  const { result: resp, model, rung } = await callWithLadder(
    modelsForMode(cfg, req.mode),
    async (m, timeoutMs) => {
      const r = await generateContent(
        cfg.apiKey!,
        m,
        generateBody(cfg, m, searchQ, isSi, basket, req.mode),
        timeoutMs,
      );
      // Gemini refused the prompt itself — deterministic, every rung would
      // block it too; fail straight to 422 instead of climbing the ladder.
      if (r.promptFeedback?.blockReason) {
        throw new ResearchError(422, 'cannot_answer', MSG.cannotAnswer, false);
      }
      // Empty 200 = wasted rung, same as a 503 — retryable, next model.
      // (Observed live 2026-07-18: gemini-3.5-flash empty-200 after 51s;
      // the rung below answered the identical question.)
      if (!responseText(r).trim()) throw new EmptyAnswerError(m);
      return r;
    },
    'generate',
    reqId,
    deadline,
  );

  const text = responseText(resp);

  const cpu0 = cpuMs();
  const response = {
    ...buildResponse(text, resp, searchQ, isSi, cfg.snippetChars),
    model,
  };
  const buildCpuMs = cpu0 === null ? null : (cpuMs() ?? cpu0) - cpu0;
  return {
    response,
    meta: { model, rung, buildCpuMs, bodyChars: resp.bodyChars ?? null },
  };
}

async function rewrite(
  cfg: Config,
  req: ResearchRequest,
  isSi: boolean,
  reqId: string,
  deadline: number,
): Promise<string> {
  if (!isSi && !req.history.length) return req.question;

  const lines = [
    "Rewrite the user's latest question as a single standalone English " +
      'search query for a Pali Canon corpus. Resolve pronouns and references ' +
      'using the conversation. Output ONLY the query, nothing else.',
    '',
  ];
  if (req.history.length) {
    lines.push('Conversation:');
    lines.push(...req.history.map((t) => `${t.role}: ${t.content}`));
    lines.push('');
  }
  lines.push(`Latest question: ${req.question}`);
  const prompt = lines.join('\n');

  // FAST-tier ladder only: rewriting is cheap and mode-independent; never spend
  // throttled thinking quota on it.
  const ladder = [
    cfg.rewriteModel,
    ...cfg.fastModels.filter((m) => m !== cfg.rewriteModel),
  ];
  const { result } = await callWithLadder(
    ladder,
    (m, timeoutMs) =>
      generateContent(
        cfg.apiKey!,
        m,
        { contents: [{ role: 'user', parts: [{ text: prompt }] }] },
        timeoutMs,
      ),
    'rewrite',
    reqId,
    deadline,
  );
  const rewritten = responseText(result).trim();
  if (!rewritten) {
    // Never fall back to the raw Sinhala query — it retrieves poorly.
    throw new ResearchError(502, 'server_error', MSG.serverError, true);
  }
  return rewritten;
}

function generateBody(
  cfg: Config,
  model: string,
  searchQ: string,
  isSi: boolean,
  basket: string | undefined,
  mode: string,
): Record<string, unknown> {
  const fileSearch: Record<string, unknown> = {
    fileSearchStoreNames: [cfg.store],
  };
  if (basket) fileSearch.metadataFilter = `basket="${basket}"`;

  const body: Record<string, unknown> = {
    systemInstruction: { parts: [{ text: systemInstruction(isSi) }] },
    contents: [{ role: 'user', parts: [{ text: searchQ }] }],
    tools: [{ fileSearch }],
  };
  if (mode === 'thinking') {
    const thinking = thinkingConfig(model);
    if (thinking) body.generationConfig = { thinkingConfig: thinking };
  }
  return body;
}

// Gemini 3.x takes thinkingLevel, 2.5 takes thinkingBudget; the wrong knob is a
// fail-fast 400, so unknown generations run uncapped rather than guessed at.
function thinkingConfig(model: string): Record<string, unknown> | null {
  if (model.startsWith('gemini-3') && THINKING_LEVEL) {
    return { thinkingLevel: THINKING_LEVEL };
  }
  if (model.startsWith('gemini-2.5') && THINKING_BUDGET_TOKENS !== null) {
    return { thinkingBudget: THINKING_BUDGET_TOKENS };
  }
  return null;
}

// Returns everything but `model`, which the caller attaches: the model comes
// from the ladder, not from post-processing, and this stays pure/benchable.
export function buildResponse(
  text: string,
  resp: GenerateResponse,
  searchQ: string,
  isSi: boolean,
  snippetChars: number,
): Omit<ResearchResponse, 'model'> {
  const citations = toCitations(text, resp, searchQ, snippetChars);
  let answerText = linkifyProseRefs(text);
  if (!answerText.includes('[[cite:')) {
    answerText = injectCitationTokens(text, resp);
  }
  return { answer: answerText, lang: isSi ? 'si' : 'en', citations };
}

const groundingChunks = (resp: GenerateResponse) =>
  resp.candidates?.[0]?.groundingMetadata?.groundingChunks ?? [];

function toCitations(
  answerText: string,
  resp: GenerateResponse,
  searchQ: string,
  snippetChars: number,
): Citation[] {
  const cites = new Map<string, Citation>();
  const terms = queryTerms(searchQ);

  // Grounding chunks, deduped by uid BEFORE snippet building — one snippet per
  // displayed source, however many chunks the retriever returned.
  for (const chunk of groundingChunks(resp)) {
    const uid = chunk.retrievedContext?.title;
    if (!uid || cites.has(uid)) continue;
    const ref = refFromUid(uid);
    const { title, body } = splitHeading(chunk.retrievedContext?.text ?? '', ref);
    const snippet = makeSnippet(body, terms, snippetChars);
    cites.set(uid, {
      uid,
      ref,
      title,
      kind: 'canon',
      snippet: snippet || null,
    });
  }

  // Refs named verbatim in the prose — resolve, drop the unknown.
  for (const m of answerText.matchAll(REF_IN_PROSE)) {
    const uid = uidFromRef(m[0]);
    if (uid && knownUid(uid) && !cites.has(uid)) {
      cites.set(uid, {
        uid,
        ref: m[0],
        title: null,
        kind: 'canon',
        snippet: null,
      });
    }
  }
  return [...cites.values()];
}

// Parens that wrap ONLY cite tokens (and separators) are dropped so a chip
// reads "…text 📖SN 15.11." instead of "(📖SN 15.11)".
const PARENS_OF_CITES = /\(\s*((?:\[\[cite:[^\]]+\]\](?:\s*(?:,|;|&|and)\s*)?)+)\)/g;

// PRIMARY chip source: refs the model wrote in prose, for known uids only.
function linkifyProseRefs(text: string): string {
  const linked = text.replace(REF_IN_PROSE, (m) => {
    const uid = uidFromRef(m);
    return uid && knownUid(uid) ? cite(uid) : m;
  });
  return linked.replace(PARENS_OF_CITES, (_, inner: string) => inner.trim());
}

// Fallback chip source: grounding_supports offsets (UTF-8 bytes → one mapping
// pass, then insert back-to-front). Multi-part answers skip injection — the
// offsets are per-part and we join parts, so placement would be wrong.
function injectCitationTokens(text: string, resp: GenerateResponse): string {
  const gm = resp.candidates?.[0]?.groundingMetadata;
  const supports = gm?.groundingSupports ?? [];
  if (!supports.length) return text;
  const parts = resp.candidates?.[0]?.content?.parts ?? [];
  if (parts.length > 1) return text;

  const chunks = groundingChunks(resp);
  const wanted: { byteEnd: number; uids: string[] }[] = [];
  for (const sup of supports) {
    const end = sup.segment?.endIndex;
    if (end === undefined) continue;
    const uids: string[] = [];
    for (const idx of sup.groundingChunkIndices ?? []) {
      const uid = chunks[idx]?.retrievedContext?.title;
      if (uid && !uids.includes(uid)) uids.push(uid);
    }
    if (uids.length) wanted.push({ byteEnd: end, uids });
  }
  if (!wanted.length) return text;

  const charAt = mapByteOffsets(text, wanted.map((w) => w.byteEnd));
  wanted.sort((a, b) => b.byteEnd - a.byteEnd);
  for (const { byteEnd, uids } of wanted) {
    const pos = charAt.get(byteEnd) ?? text.length;
    text = text.slice(0, pos) + uids.map(cite).join('') + text.slice(pos);
  }
  return text;
}

function mapByteOffsets(text: string, byteOffsets: number[]): Map<number, number> {
  const sorted = [...new Set(byteOffsets)].sort((a, b) => a - b);
  const map = new Map<number, number>();
  let bytes = 0;
  let k = 0;
  for (let i = 0; i < text.length && k < sorted.length; ) {
    while (k < sorted.length && sorted[k]! <= bytes) {
      map.set(sorted[k]!, i);
      k++;
    }
    const cp = text.codePointAt(i)!;
    bytes += cp < 0x80 ? 1 : cp < 0x800 ? 2 : cp < 0x10000 ? 3 : 4;
    i += cp < 0x10000 ? 1 : 2;
  }
  while (k < sorted.length) {
    map.set(sorted[k]!, text.length);
    k++;
  }
  return map;
}
