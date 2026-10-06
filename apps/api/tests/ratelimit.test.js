// The live-test switch turns limits off only in test mode, never in production.

const test = require('node:test');
const assert = require('node:assert/strict');
const { rateLimit, reset } = require('../lib/ratelimit');

function hits(limiter, count) {
  let passed = 0;
  for (let i = 0; i < count; i++) {
    const res = { set() {}, status: () => ({ json() {} }) };
    limiter({ ip: '203.0.113.9' }, res, () => passed++);
  }
  return passed;
}

test('EXERLY_RATE_LIMITS=off lifts limits only when NODE_ENV is test', (t) => {
  const saved = { mode: process.env.NODE_ENV, switch: process.env.EXERLY_RATE_LIMITS };
  t.after(() => {
    process.env.NODE_ENV = saved.mode;
    if (saved.switch === undefined) delete process.env.EXERLY_RATE_LIMITS;
    else process.env.EXERLY_RATE_LIMITS = saved.switch;
    reset();
  });
  const limiter = rateLimit({ name: 'switch-test', max: 2, windowMs: 60_000 });
  process.env.EXERLY_RATE_LIMITS = 'off';
  process.env.NODE_ENV = 'production';
  assert.equal(hits(limiter, 5), 2, 'production ignores the switch');
  reset();
  process.env.NODE_ENV = 'test';
  assert.equal(hits(limiter, 5), 5);
  delete process.env.EXERLY_RATE_LIMITS;
  reset();
  assert.equal(hits(limiter, 5), 2, 'test mode alone keeps limits');
});
