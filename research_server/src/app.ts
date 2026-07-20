// Platform-neutral Hono app (Web-standard Request/Response only). Entries:
// index.ts (Cloudflare Workers) and node.ts (any Node host).

import { Hono } from 'hono';
import { cors } from 'hono/cors';
import type { ContentfulStatusCode } from 'hono/utils/http-status';
import { EnvVars, loadConfig } from './config.js';
import { parseRequest } from './contracts.js';
import { classifyUpstream, MSG, ResearchError } from './errors.js';
import { answer } from './pipeline.js';
import { cannedAnswer } from './stub.js';
import { cpuMs } from './timing.js';

export const app = new Hono<{ Bindings: EnvVars }>();

app.use(
  '*',
  cors({
    origin: (origin, c) => {
      const allowed = loadConfig(c.env).corsOrigins;
      if (allowed.includes('*')) return '*';
      return allowed.includes(origin) ? origin : allowed[0] ?? '';
    },
    allowMethods: ['GET', 'POST', 'OPTIONS'],
  }),
);

app.get('/', (c) => {
  const cfg = loadConfig(c.env);
  return c.json({
    service: 'wisdom-research',
    mode: cfg.stub ? 'stub' : 'live',
    see: 'POST /research',
  });
});

app.get('/health', (c) => {
  const cfg = loadConfig(c.env);
  return c.json({
    status: 'ok',
    mode: cfg.stub ? 'stub' : 'live',
    model: cfg.stub ? null : cfg.fastModels[0],
    fast_models: cfg.stub ? null : cfg.fastModels,
    thinking_models: cfg.stub ? null : cfg.thinkingModels,
    store_configured: Boolean(cfg.store),
  });
});

app.post('/research', async (c) => {
  const cfg = loadConfig(c.env);
  const reqId = crypto.randomUUID().slice(0, 6);
  const started = Date.now();
  const secs = () => ((Date.now() - started) / 1000).toFixed(1);
  const cpu0 = cpuMs();
  const cpu = () =>
    cpu0 === null ? '' : ` cpu=${((cpuMs() ?? cpu0) - cpu0).toFixed(1)}ms`;
  let mode = '-';
  try {
    if (cfg.appToken && c.req.header('x-app-token') !== cfg.appToken) {
      throw new ResearchError(401, 'not_authorised', MSG.notAuthorised, false);
    }
    let body: unknown;
    try {
      body = await c.req.json();
    } catch {
      throw new ResearchError(400, 'bad_request', MSG.badRequest, false);
    }
    const req = parseRequest(body);
    if (!req || !req.question.trim()) {
      throw new ResearchError(400, 'bad_request', MSG.badRequest, false);
    }
    mode = req.mode;
    // Breadcrumb before any Gemini work. A request the platform kills mid-CPU
    // (1102 / outcome "exceededCpu") never reaches the summary lines below —
    // this line is then the only trace tying reqId+mode to the platform's
    // exceededCpu record in the tail.
    console.log(`research[${reqId}] POST /research mode=${mode} start`);

    const { response, meta } = cfg.stub
      ? {
          response: cannedAnswer(req.question),
          meta: { model: 'stub', rung: 0, buildCpuMs: null, bodyChars: null },
        }
      : await answer(cfg, req, reqId);

    const build =
      meta.buildCpuMs === null ? '' : ` build=${meta.buildCpuMs.toFixed(1)}ms`;
    // Payload size of the answer call — the live CPU driver (KB of chars).
    const payload =
      meta.bodyChars === null ? '' : ` body=${Math.round(meta.bodyChars / 1024)}KB`;
    console.log(
      `research[${reqId}] POST /research mode=${mode} lang=${response.lang} ` +
        `model=${meta.model} rung=${meta.rung} citations=${response.citations.length} ` +
        `200 in ${secs()}s${cpu()}${build}${payload}`,
    );
    return c.json(response);
  } catch (e) {
    const err = e instanceof ResearchError ? e : classifyUpstream(e);
    if (!(e instanceof ResearchError)) {
      console.error(`research[${reqId}] unhandled:`, e);
    }
    console.log(
      `research[${reqId}] POST /research mode=${mode} ${err.status} ${err.code} ` +
        `in ${secs()}s${cpu()}`,
    );
    return c.json(err.toBody(), err.status as ContentfulStatusCode);
  }
});
