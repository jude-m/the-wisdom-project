// Raw fetch against the Gemini REST generateContent endpoint — no SDK on the
// request path. Waiting on this fetch costs no Workers CPU time.

import { RUNG_TIMEOUT_MS } from './config.js';
import { GeminiError, isRetryable, isTimeoutError } from './errors.js';

const BASE = 'https://generativelanguage.googleapis.com/v1beta/models';

export interface Part {
  text?: string;
  thought?: boolean;
}

export interface GroundingChunk {
  retrievedContext?: { title?: string; text?: string };
}

export interface GroundingSupport {
  segment?: { partIndex?: number; startIndex?: number; endIndex?: number };
  groundingChunkIndices?: number[];
}

export interface GenerateResponse {
  /** Present when Gemini refused the prompt itself (safety block). The answer
   *  is empty on every model, so the ladder must not retry it. */
  promptFeedback?: { blockReason?: string };
  candidates?: {
    content?: { parts?: Part[] };
    groundingMetadata?: {
      groundingChunks?: GroundingChunk[];
      groundingSupports?: GroundingSupport[];
    };
  }[];
  /** Ours, not Gemini's: decoded body length in chars (UTF-16 code units —
   *  the quantity JSON.parse actually walks), for the `body=` log field. */
  bodyChars?: number;
}

export async function generateContent(
  apiKey: string,
  model: string,
  body: Record<string, unknown>,
  timeoutMs: number = RUNG_TIMEOUT_MS,
): Promise<GenerateResponse> {
  const res = await fetch(`${BASE}/${model}:generateContent`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-goog-api-key': apiKey,
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!res.ok) {
    let rpcStatus = '';
    let message = res.statusText;
    try {
      const err = ((await res.json()) as { error?: { status?: string; message?: string } }).error;
      rpcStatus = err?.status ?? '';
      message = err?.message ?? message;
    } catch {
      // non-JSON error body — keep the statusText
    }
    throw new GeminiError(res.status, rpcStatus, message);
  }
  // Decode + parse ourselves (res.json() does the same work) so the payload
  // size can ride back on the response — live CPU tracks THIS, not our
  // post-processing (see the knowledge doc's CPU map).
  const raw = await res.text();
  const resp = JSON.parse(raw) as GenerateResponse;
  resp.bodyChars = raw.length;
  return resp;
}

export function responseText(resp: GenerateResponse): string {
  const parts = resp.candidates?.[0]?.content?.parts ?? [];
  return parts
    .filter((p) => p.text && !p.thought)
    .map((p) => p.text)
    .join('');
}

// Walk a model ladder, falling to the next rung only on a transient error
// (429 / 503 / our timeout). Anything else fails fast — a malformed request
// won't fare better on a different model. `deadline` (epoch ms) caps the whole
// ladder: each rung's timeout shrinks to the time left, and no new rung starts
// past it — the client has already hung up by then, so a later rung would only
// burn quota on an answer nobody receives.
export async function callWithLadder<T>(
  models: string[],
  call: (model: string, timeoutMs: number) => Promise<T>,
  label: string,
  reqId: string,
  deadline?: number,
): Promise<{ result: T; model: string; rung: number }> {
  let lastErr: unknown;
  for (let i = 0; i < models.length; i++) {
    // Out of budget before this rung even starts — surface the prior failure
    // rather than fire a doomed sub-millisecond request nobody will read.
    if (deadline !== undefined && i > 0 && Date.now() >= deadline) throw lastErr;
    const model = models[i]!;
    const started = Date.now();
    const timeoutMs =
      deadline === undefined
        ? RUNG_TIMEOUT_MS
        : Math.max(1, Math.min(RUNG_TIMEOUT_MS, deadline - started));
    try {
      const result = await call(model, timeoutMs);
      return { result, model, rung: i + 1 };
    } catch (e) {
      lastErr = e;
      const secs = ((Date.now() - started) / 1000).toFixed(1);
      const why = isTimeoutError(e)
        ? `our ${(timeoutMs / 1000).toFixed(0)}s ceiling`
        : e instanceof GeminiError
          ? `${e.httpStatus} ${e.rpcStatus}`.trim()
          : String(e);
      const outOfTime = deadline !== undefined && Date.now() >= deadline;
      const last = i === models.length - 1;
      if (!isRetryable(e) || last || outOfTime) {
        const reason = !isRetryable(e)
          ? 'not retriable'
          : last
            ? 'ladder exhausted'
            : 'deadline exhausted';
        console.warn(
          `research[${reqId}] ${label} rung ${i + 1}/${models.length} ${model} ` +
            `failed after ${secs}s (${why}) — ${reason}`,
        );
        throw e;
      }
      console.warn(
        `research[${reqId}] ${label} rung ${i + 1}/${models.length} ${model} ` +
          `unavailable after ${secs}s (${why}); falling back to ${models[i + 1]}`,
      );
    }
  }
  throw new Error('empty model ladder');
}
