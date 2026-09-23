// Security response headers.
//
// This API only ever returns JSON, so the headers that matter are few. helmet
// would set a dozen more that are all about HTML documents (CSP, permissions
// policy) and would be inert here. Not worth the dependency.

function securityHeaders(req, res, next) {
  res.set('X-Content-Type-Options', 'nosniff');
  res.set('X-Frame-Options', 'DENY');
  res.set('Referrer-Policy', 'no-referrer');
  res.set('X-DNS-Prefetch-Control', 'off');
  res.set('Cross-Origin-Resource-Policy', 'same-site');
  // Only meaningful over TLS, and setting it in development would pin
  // localhost to https in the browser's HSTS store.
  if (process.env.NODE_ENV === 'production') {
    res.set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  }
  res.removeHeader('X-Powered-By');
  next();
}

const DEFAULT_ORIGINS = [
  'http://localhost:3000',
  'http://127.0.0.1:3000',
  'http://localhost:5173',
  'http://127.0.0.1:5173',
  'https://exerlyfitness.com',
  'https://www.exerlyfitness.com',
  'https://exerly-fitness-93dyl.ondigitalocean.app',
  'https://whoisaldo.github.io',
  'http://localhost:8081',
  'http://localhost:19000',
  'http://localhost:19006',
];

// Private ranges so a phone on the same wifi can reach a dev server.
const PRIVATE_NETWORK = [
  /^http:\/\/192\.168\.\d{1,3}\.\d{1,3}(:\d+)?$/,
  /^http:\/\/10\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?$/,
  /^http:\/\/172\.(1[6-9]|2[0-9]|3[0-1])\.\d{1,3}\.\d{1,3}(:\d+)?$/,
  // Tailscale CGNAT range: this machine is reachable at 100.80.149.7 on the tailnet.
  /^http:\/\/100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.\d{1,3}\.\d{1,3}(:\d+)?$/,
];

function corsOrigin(extra = []) {
  const allowed = [...DEFAULT_ORIGINS, ...extra];
  return (origin, callback) => {
    // No Origin header means a native app or a server-to-server call, neither
    // of which the browser same-origin policy applies to.
    if (!origin) return callback(null, true);
    const ok = allowed.includes(origin) || PRIVATE_NETWORK.some((pattern) => pattern.test(origin));
    return callback(null, ok);
  };
}

module.exports = { securityHeaders, corsOrigin, DEFAULT_ORIGINS };
