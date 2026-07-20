// Model tiers for the app's Fast/Thinking switch. Each tier is a fallback
// ladder, highest capability first; the pipeline falls to the next rung on a
// transient error (429 rate limit / 503 high demand) only.
export const FAST_MODELS = ['gemini-3.1-flash-lite', 'gemini-2.5-flash-lite'];
export const THINKING_MODELS = [
  'gemini-3.5-flash',
  'gemini-3-flash-preview',
  'gemini-2.5-flash',
];

// Deliberation caps for the thinking tier (a stopwatch, not a quality grade).
// Gemini 3.x takes thinkingLevel, Gemini 2.5 takes thinkingBudget tokens;
// sending the wrong knob is a fail-fast 400, hence the per-generation split.
export const THINKING_LEVEL: string | null = 'LOW';
export const THINKING_BUDGET_TOKENS: number | null = 4096;

// Per-rung ceiling: a refusal can take far longer than an answer (measured
// 369.7s just to 503). Must stay above the slowest legitimate thinking answer
// (~170s at LOW).
export const RUNG_TIMEOUT_MS = 210_000;

// Whole-request deadline per mode, strictly inside the app's HTTP timeouts
// (60s fast / 5min thinking — research_remote_datasource._timeoutFor); the
// margin covers transit + cold start on the way in and the response on the
// way back. Past it the client has already hung up, so finishing the ladder
// would only burn quota on an answer nobody receives.
export const DEADLINE_FAST_MS = 55_000;
export const DEADLINE_THINKING_MS = 290_000;

export const deadlineForMode = (mode: string): number =>
  mode === 'thinking' ? DEADLINE_THINKING_MS : DEADLINE_FAST_MS;

export type EnvVars = Record<string, string | undefined>;

export interface Config {
  stub: boolean;
  apiKey?: string;
  store?: string;
  fastModels: string[];
  thinkingModels: string[];
  rewriteModel: string;
  snippetChars: number;
  corsOrigins: string[];
  appToken?: string;
}

const csv = (raw: string | undefined): string[] =>
  (raw ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

export function loadConfig(env: EnvVars): Config {
  const fastOverride = csv(env.RESEARCH_FAST_MODELS);
  const thinkingOverride = csv(env.RESEARCH_THINKING_MODELS);
  const fastModels = fastOverride.length ? fastOverride : FAST_MODELS;
  const thinkingModels = thinkingOverride.length
    ? thinkingOverride
    : THINKING_MODELS;
  const cors = csv(env.RESEARCH_CORS_ORIGINS);
  return {
    stub: ['1', 'true', 'yes', 'on'].includes(
      (env.RESEARCH_STUB ?? '1').trim().toLowerCase(),
    ),
    apiKey: env.GEMINI_API_KEY || undefined,
    store: env.RESEARCH_STORE || undefined,
    fastModels,
    thinkingModels,
    rewriteModel: env.RESEARCH_REWRITE_MODEL || fastModels[0]!,
    snippetChars: Number(env.RESEARCH_SNIPPET_CHARS ?? '220') || 220,
    corsOrigins: cors.length ? cors : ['*'],
    appToken: env.RESEARCH_APP_TOKEN || undefined,
  };
}

export const modelsForMode = (cfg: Config, mode: string): string[] =>
  mode === 'thinking' ? cfg.thinkingModels : cfg.fastModels;
