// CPU benchmark for the citation-heavy worst case (Python baseline: 27ms).
// Builds 22 grounding chunks from real bilara-data suttas, a ~5k-char answer
// with 21 prose refs, plus a no-prose-refs variant that exercises the
// grounding-support injection + byte→char mapping. Measures process.cpuUsage
// over the full in-process request work: parse + buildResponse + stringify.

import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseRequest } from '../src/contracts.js';
import { GenerateResponse } from '../src/gemini.js';
import { buildResponse } from '../src/pipeline.js';
import { refFromUid } from '../src/refs.js';

const BUDGET_MS = 10;
const CHUNKS = 22;

const bilaraDir =
  process.env.BILARA_DATA_DIR ??
  join(
    fileURLToPath(new URL('.', import.meta.url)),
    '../../../deprecated/research_server/bilara-data',
  );

function walk(dir: string, out: { path: string; size: number }[]): void {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    const st = statSync(p);
    if (st.isDirectory()) walk(p, out);
    else if (name.endsWith('-sujato.json')) out.push({ path: p, size: st.size });
  }
}

// Replicates ingest.load_unit: "<heading segments>\n<body segments>".
function loadUnit(path: string): { uid: string; text: string } {
  const segs = JSON.parse(readFileSync(path, 'utf-8')) as Record<string, string>;
  const uid = Object.keys(segs)[0]!.split(':')[0]!;
  const head: string[] = [];
  const body: string[] = [];
  for (const [key, val] of Object.entries(segs)) {
    const v = val.trim();
    if (!v) continue;
    (key.startsWith(`${uid}:0.`) ? head : body).push(v);
  }
  return { uid, text: `${head.join(' ')}\n${body.join(' ')}` };
}

const files: { path: string; size: number }[] = [];
for (const sub of ['dn', 'mn', 'sn']) {
  walk(join(bilaraDir, 'translation/en/sujato/sutta', sub), files);
}
files.sort((a, b) => b.size - a.size);
const units = files.slice(0, 14).map((f) => loadUnit(f.path));

// 22 chunks over 14 suttas — the surplus duplicates real File Search behaviour
// (a long sutta split into several chunks sharing one uid).
const chunks = Array.from({ length: CHUNKS }, (_, i) => {
  const u = units[i % units.length]!;
  return { retrievedContext: { title: u.uid, text: u.text } };
});

const searchQ =
  'How does the Buddha describe the beginningless cycle of transmigration, ' +
  'the tears and mothers and death and rebirth, the mustard seed, grass and sticks?';

// ~5k-char answer citing 21 distinct refs in prose.
const refs = units.map((u) => refFromUid(u.uid));
while (refs.length < 21) refs.push(`SN 15.${refs.length}`);
let answerProse = '';
let i = 0;
while (answerProse.length < 5000) {
  const ref = refs[i % 21]!;
  answerProse +=
    `The Buddha teaches that the cycle of transmigration is without ` +
    `discoverable beginning, and beings shrouded by ignorance wander on ` +
    `(${ref}). The stream of tears shed while wandering exceeds the oceans, ` +
    `for mothers and fathers lost are beyond counting (${refs[(i + 7) % 21]}). `;
  i++;
}

// Injection variant: no prose refs, Sinhala text (multibyte → real byte→char
// work), 21 grounding supports.
let answerSi = '';
while (answerSi.length < 5000) {
  answerSi +=
    'සසර ගමනේ ආරම්භයක් නොපෙනෙන බව බුදුරජාණන් වහන්සේ දේශනා කරති. ' +
    'අවිද්‍යාවෙන් වැසුණු සත්ත්වයෝ තණ්හාවෙන් බැඳී සසර සරති. ';
}
const siBytes = Buffer.byteLength(answerSi, 'utf-8');
const supports = Array.from({ length: 21 }, (_, k) => ({
  segment: { endIndex: Math.floor((siBytes * (k + 1)) / 22) },
  groundingChunkIndices: [k % CHUNKS, (k + 3) % CHUNKS],
}));

const respProse: GenerateResponse = {
  candidates: [
    {
      content: { parts: [{ text: answerProse }] },
      groundingMetadata: { groundingChunks: chunks },
    },
  ],
};
const respInject: GenerateResponse = {
  candidates: [
    {
      content: { parts: [{ text: answerSi }] },
      groundingMetadata: { groundingChunks: chunks, groundingSupports: supports },
    },
  ],
};

const requestJson = JSON.stringify({
  question: searchQ,
  history: [],
  mode: 'thinking',
});

function oneRequest(resp: GenerateResponse, text: string, isSi: boolean): string {
  const req = parseRequest(JSON.parse(requestJson));
  if (!req) throw new Error('parse failed');
  const response = buildResponse(text, resp, searchQ, isSi, 220);
  return JSON.stringify(response);
}

function measure(label: string, run: () => void, iterations: number): number {
  const before = process.cpuUsage();
  for (let n = 0; n < iterations; n++) run();
  const after = process.cpuUsage(before);
  const ms = (after.user + after.system) / 1000 / iterations;
  const verdict = ms < BUDGET_MS ? 'PASS' : 'FAIL';
  console.log(`${verdict}  ${label}: ${ms.toFixed(2)}ms CPU/request`);
  return ms;
}

console.log(
  `fixture: ${CHUNKS} chunks from ${units.length} suttas ` +
    `(largest ${Math.round(units[0]!.text.length / 1000)}k chars), ` +
    `answer ${answerProse.length} chars / 21 refs\n`,
);

// Cold = first request in a fresh isolate (empty fold cache).
const cold = measure('cold  prose-refs path', () => oneRequest(respProse, answerProse, false), 1);
const warmProse = measure('warm  prose-refs path', () => oneRequest(respProse, answerProse, false), 50);
const warmInject = measure('warm  injection path (byte→char)', () => oneRequest(respInject, answerSi, true), 50);

const worst = Math.max(cold, warmProse, warmInject);
console.log(`\nworst case: ${worst.toFixed(2)}ms — budget ${BUDGET_MS}ms — ${worst < BUDGET_MS ? 'PASS' : 'FAIL'}`);
process.exit(worst < BUDGET_MS ? 0 : 1);
