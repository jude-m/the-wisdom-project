import { serve } from '@hono/node-server';
import { app } from './app.js';

const port = Number(process.env.PORT ?? 8082);
serve({ fetch: (req) => app.fetch(req, process.env), port }, (info) =>
  console.log(`wisdom-research (node) listening on :${info.port}`),
);
