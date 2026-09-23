// Fixed-window rate limiter.
//
// Hand-rolled rather than pulling in express-rate-limit: the whole thing is 40
// lines, and a single-instance API doesn't need a shared store. If this ever
// runs on more than one instance the counters become per-instance, which is
// worth remembering before scaling out.

const buckets = new Map();

// One sweep for all limiters. Without it, every unique IP that ever hits the
// API stays in memory forever.
const SWEEP_MS = 5 * 60 * 1000;
const sweeper = setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of buckets) {
    if (now > entry.resetAt) buckets.delete(key);
  }
}, SWEEP_MS);
sweeper.unref?.();

function clientKey(req) {
  // trust proxy is set on the app, so req.ip already reflects X-Forwarded-For
  // when running behind DigitalOcean's load balancer.
  return req.ip || req.socket?.remoteAddress || 'unknown';
}

/**
 * @param {object} options
 * @param {number} options.max requests allowed per window
 * @param {number} options.windowMs window length
 * @param {string} options.name namespace, so two limiters don't share counters
 * @param {(req) => string} [options.key] defaults to client IP
 */
function rateLimit({ max, windowMs, name, key = clientKey, message }) {
  return (req, res, next) => {
    const id = `${name}:${key(req)}`;
    const now = Date.now();
    let entry = buckets.get(id);

    if (!entry || now > entry.resetAt) {
      entry = { count: 0, resetAt: now + windowMs };
      buckets.set(id, entry);
    }

    entry.count += 1;
    const remaining = Math.max(0, max - entry.count);
    res.set('RateLimit-Limit', String(max));
    res.set('RateLimit-Remaining', String(remaining));
    res.set('RateLimit-Reset', String(Math.ceil((entry.resetAt - now) / 1000)));

    if (entry.count > max) {
      res.set('Retry-After', String(Math.ceil((entry.resetAt - now) / 1000)));
      return res.status(429).json({
        message: message || 'Too many requests. Try again shortly.',
      });
    }
    next();
  };
}

function reset() {
  buckets.clear();
}

module.exports = { rateLimit, reset, clientKey };
