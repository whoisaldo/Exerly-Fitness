// Boots the real app against an in-memory SQLite database.
//
// node --test forks a process per file, so every test file gets its own
// database. Tests can't leak state into each other and none of them need
// teardown beyond closing the server.

process.env.DB_MODE = process.env.EXERLY_TEST_DB === 'mongo' ? 'mongo' : 'local';
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-secret-not-used-anywhere-real';
process.env.ADMIN_EMAILS = 'admin@exerly.test';

const store = require('../../data');
const { createApp } = require('../../app');
const { reset: resetRateLimits } = require('../../lib/ratelimit');

// Errors are expected here; printing every stack would bury the real failures.
const quietLogger = { error: () => {}, warn: () => {}, log: () => {} };

async function startServer() {
  if (process.env.EXERLY_TEST_DB === 'mongo') {
    const uri = new URL(process.env.EXERLY_TEST_MONGODB_URI);
    uri.pathname = `/exerly_test_${process.pid}`;
    await store.connect({ uri: uri.toString() });
  } else {
    await store.connect({ file: ':memory:' });
  }
  resetRateLimits();

  const app = createApp({ logger: quietLogger });
  const server = await new Promise((resolve) => {
    const s = app.listen(0, '127.0.0.1', () => resolve(s));
  });

  const base = `http://127.0.0.1:${server.address().port}`;

  async function request(method, path, { body, token, headers = {} } = {}) {
    const res = await fetch(`${base}${path}`, {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...headers,
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });

    const text = await res.text();
    let json = null;
    try {
      json = text ? JSON.parse(text) : null;
    } catch {
      json = text;
    }
    return { status: res.status, body: json, headers: res.headers };
  }

  return {
    base,
    store,
    get: (p, o) => request('GET', p, o),
    post: (p, body, o) => request('POST', p, { ...o, body }),
    put: (p, body, o) => request('PUT', p, { ...o, body }),
    patch: (p, body, o) => request('PATCH', p, { ...o, body }),
    del: (p, o) => request('DELETE', p, o),
    async close() {
      await new Promise((resolve) => server.close(resolve));
      await store.disconnect();
    },
  };
}

// Signs up a user and returns their token, so a test needing a session is one
// line instead of six.
//
// Rate-limit counters are cleared first because every request in the suite
// comes from 127.0.0.1 and would otherwise trip the 5-signups-per-hour limit
// after the fifth test. The limits themselves stay at their production values;
// tests that care about them drive the endpoint directly.
async function signUp(client, overrides = {}) {
  resetRateLimits();
  const payload = {
    name: 'Test User',
    email: `user${Math.random().toString(36).slice(2, 10)}@exerly.test`,
    password: 'correct-horse-battery',
    timezone: 'America/Detroit',
    ...overrides,
  };
  const res = await client.post('/signup', payload);
  if (res.status !== 201) {
    throw new Error(`signUp failed: ${res.status} ${JSON.stringify(res.body)}`);
  }
  return { ...payload, token: res.body.token, user: res.body.user };
}

module.exports = { startServer, signUp, store };
