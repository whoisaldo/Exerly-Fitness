const test = require('node:test');
const assert = require('node:assert');
const { startServer, signUp } = require('./helpers/server');

let api;
test.before(async () => {
  api = await startServer();
});
test.after(async () => api.close());

test('signup returns a token and a serialized user', async () => {
  const res = await api.post('/signup', {
    name: 'Aldo',
    email: 'aldo@exerly.test',
    password: 'correct-horse-battery',
    timezone: 'America/Detroit',
  });

  assert.equal(res.status, 201);
  assert.ok(res.body.token);
  assert.equal(res.body.user.email, 'aldo@exerly.test');
  assert.equal(res.body.user.timezone, 'America/Detroit');
  assert.equal(res.body.user.isAdmin, false);
  assert.ok(!('hash' in res.body.user), 'password hash must never be serialized');
});

test('signup rejects a password under 8 characters', async () => {
  const res = await api.post('/signup', {
    name: 'Short',
    email: 'short@exerly.test',
    password: 'abc123',
  });
  assert.equal(res.status, 400);
  assert.match(res.body.message, /at least 8/);
});

test('signup rejects a duplicate email', async () => {
  const res = await api.post('/signup', {
    name: 'Aldo Again',
    email: 'aldo@exerly.test',
    password: 'correct-horse-battery',
  });
  assert.equal(res.status, 409);
});

test('login succeeds and rejects a wrong password identically to a missing user', async () => {
  const ok = await api.post('/login', {
    email: 'aldo@exerly.test',
    password: 'correct-horse-battery',
  });
  assert.equal(ok.status, 200);
  assert.ok(ok.body.token);

  const wrongPassword = await api.post('/login', {
    email: 'aldo@exerly.test',
    password: 'wrong-password-here',
  });
  const noSuchUser = await api.post('/login', {
    email: 'nobody@exerly.test',
    password: 'wrong-password-here',
  });

  assert.equal(wrongPassword.status, 401);
  assert.equal(noSuchUser.status, 401);
  assert.equal(
    wrongPassword.body.message,
    noSuchUser.body.message,
    'the response must not reveal whether an email is registered'
  );
});

test('an email in ADMIN_EMAILS is promoted on signup', async () => {
  const res = await api.post('/signup', {
    name: 'Admin',
    email: 'admin@exerly.test',
    password: 'correct-horse-battery',
  });
  assert.equal(res.body.user.isAdmin, true);
});

test('protected routes reject a missing or malformed token', async () => {
  assert.equal((await api.get('/api/me')).status, 401);
  assert.equal((await api.get('/api/me', { token: 'not-a-jwt' })).status, 401);
  assert.equal((await api.get('/api/me', { headers: { Authorization: 'Basic abc' } })).status, 401);
});

test('refresh issues a new token for a valid session', async () => {
  const user = await signUp(api);
  const res = await api.post('/auth/refresh', {}, { token: user.token });
  assert.equal(res.status, 200);
  assert.ok(res.body.token);

  const me = await api.get('/api/me', { token: res.body.token });
  assert.equal(me.status, 200);
  assert.equal(me.body.email, user.email);
});

test('change-password requires the current password and then works', async () => {
  const user = await signUp(api);

  const wrong = await api.post(
    '/api/change-password',
    { currentPassword: 'nope-nope-nope', newPassword: 'a-brand-new-password' },
    { token: user.token }
  );
  assert.equal(wrong.status, 401);

  const ok = await api.post(
    '/api/change-password',
    { currentPassword: user.password, newPassword: 'a-brand-new-password' },
    { token: user.token }
  );
  assert.equal(ok.status, 200);

  const relogin = await api.post('/login', {
    email: user.email,
    password: 'a-brand-new-password',
  });
  assert.equal(relogin.status, 200);
});

test('repeated failed logins are rate limited', async () => {
  const attempts = [];
  for (let i = 0; i < 12; i++) {
    attempts.push(
      await api.post('/login', { email: 'aldo@exerly.test', password: 'definitely-wrong' })
    );
  }
  const limited = attempts.filter((r) => r.status === 429);
  assert.ok(limited.length > 0, 'brute forcing should hit a limit');
  assert.ok(limited[0].headers.get('retry-after'), 'a 429 should say when to retry');
});

test('an unexpected server error does not leak internals in production mode', async () => {
  // The error handler branches on NODE_ENV, and the tests run with it set to
  // "test", so this pins the production branch specifically.
  const { errorHandler } = require('../lib/errors');
  const previous = process.env.NODE_ENV;
  process.env.NODE_ENV = 'production';

  const captured = {};
  const res = {
    status(code) {
      captured.status = code;
      return this;
    },
    json(body) {
      captured.body = body;
    },
  };
  errorHandler({ error: () => {} })(
    new Error('connect ECONNREFUSED 10.0.0.5:27017'),
    { method: 'GET', path: '/x' },
    res
  );
  process.env.NODE_ENV = previous;

  assert.equal(captured.status, 500);
  assert.ok(!JSON.stringify(captured.body).includes('27017'), 'internal detail leaked');
  assert.ok(!captured.body.stack);
});

test('security headers are set on every response', async () => {
  const res = await api.get('/api/health');
  assert.equal(res.headers.get('x-content-type-options'), 'nosniff');
  assert.equal(res.headers.get('x-frame-options'), 'DENY');
  assert.equal(res.headers.get('x-powered-by'), null);
});

test('health reports the driver and a connected database', async () => {
  const res = await api.get('/api/health');
  assert.equal(res.status, 200);
  assert.equal(res.body.status, 'healthy');
  assert.equal(
    res.body.database.driver,
    process.env.EXERLY_TEST_DB === 'mongo' ? 'mongo' : 'sqlite'
  );
});
