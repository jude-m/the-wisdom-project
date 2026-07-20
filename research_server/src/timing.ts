// Debug CPU clock. Real on Node (process.cpuUsage); null on Workers, whose
// isolates hide CPU and freeze clocks during compute — there the platform's
// invocation logs report CPU (observability is on in wrangler.jsonc).
// Process-wide, so concurrent requests inflate each other: debug-grade only.

const hasCpu =
  typeof process !== 'undefined' && typeof process.cpuUsage === 'function';

export function cpuMs(): number | null {
  if (!hasCpu) return null;
  const u = process.cpuUsage();
  return (u.user + u.system) / 1000;
}
