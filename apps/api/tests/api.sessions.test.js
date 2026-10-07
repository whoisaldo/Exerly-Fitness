const test = require('node:test');
const assert = require('node:assert/strict');
const jwt = require('jsonwebtoken');
const { createHash } = require('node:crypto');
const { startServer, signUp } = require('./helpers/server');
const { canonicalJSON } = require('../lib/mutations');

let api;
test.before(async () => {
  api = await startServer();
});
test.after(async () => api.close());

async function loginModern(user) {
  const result = await api.post(
    '/login',
    { email: user.email, password: user.password },
    {
      headers: { 'X-Session-Protocol': '2', 'X-Device-Name': 'Test phone' },
    }
  );
  assert.equal(result.status, 200);
  return result.body;
}

test('modern clients get short access tokens and separately hashed rotating refresh credentials', async () => {
  const user = await signUp(api);
  const session = await loginModern(user);
  const claims = jwt.decode(session.token);
  assert.equal(claims.exp - claims.iat, 900);
  assert.equal(claims.sub, user.user._id);
  const stored = await api.store.findOne('sessions', { session_id: session.sessionId });
  assert.ok(stored.refresh_hash);
  assert.ok(!JSON.stringify(stored).includes(session.refreshToken));
  const rotated = await api.post(
    '/auth/token',
    { refreshToken: session.refreshToken },
    { headers: { 'Idempotency-Key': 'refresh-operation-0001' } }
  );
  assert.equal(rotated.status, 200);
  assert.notEqual(rotated.body.refreshToken, session.refreshToken);
  assert.equal((await api.get('/api/me', { token: rotated.body.token })).status, 200);
});

test('a refresh acknowledgement can be lost and recovered without another rotation', async () => {
  const user = await signUp(api);
  const session = await loginModern(user);
  const options = { headers: { 'Idempotency-Key': 'lost-refresh-operation' } };
  const body = { refreshToken: session.refreshToken };
  const results = await Promise.all(
    Array.from({ length: 4 }, () => api.post('/auth/token', body, options))
  );
  for (const result of results) {
    assert.equal(result.status, 200);
    assert.equal(result.body.refreshToken, results[0].body.refreshToken);
  }
  const stored = await api.store.findOne('sessions', { session_id: session.sessionId });
  assert.equal(stored.generation, 1);
  assert.equal(
    (await api.post('/auth/token', body, { headers: { 'Idempotency-Key': 'different-operation' } }))
      .status,
    401
  );
});

test('logout revokes access and refresh credentials on the server', async () => {
  const user = await signUp(api);
  const session = await loginModern(user);
  assert.equal((await api.post('/auth/logout', {}, { token: session.token })).status, 200);
  assert.equal((await api.get('/api/me', { token: session.token })).status, 401);
  assert.equal(
    (
      await api.post(
        '/auth/token',
        { refreshToken: session.refreshToken },
        { headers: { 'Idempotency-Key': 'after-logout-refresh' } }
      )
    ).status,
    401
  );
});

test('password changes revoke every device session', async () => {
  const user = await signUp(api);
  const one = await loginModern(user);
  const two = await loginModern(user);
  assert.equal(
    (
      await api.post(
        '/api/change-password',
        { currentPassword: user.password, newPassword: 'another-long-password' },
        { token: one.token }
      )
    ).status,
    200
  );
  for (const session of [one, two]) {
    assert.equal((await api.get('/api/me', { token: session.token })).status, 401);
  }
});

test('a late session from before a password change cannot renew against newer credentials', async () => {
  const user = await signUp(api);
  const stale = await api.store.findById('users', user.user._id);
  const renewed = await loginModern(user);
  const operation = { headers: { 'Idempotency-Key': 'before-password-change-rotation' } };
  const rotated = await api.post('/auth/token', { refreshToken: renewed.refreshToken }, operation);
  assert.equal(rotated.status, 200);
  assert.equal(
    (
      await api.post(
        '/api/change-password',
        { currentPassword: user.password, newPassword: 'replacement-long-password' },
        { token: rotated.body.token }
      )
    ).status,
    200
  );
  // Model a login that verified the old hash before the password transaction
  // and inserted its session only after that transaction revoked existing rows.
  const { createSession } = require('../lib/sessions');
  const late = await createSession(stale, {
    get: (header) => (header === 'X-Session-Protocol' ? '2' : undefined),
  });
  assert.equal((await api.get('/api/me', { token: late.token })).status, 401);
  assert.equal(
    (
      await api.post(
        '/auth/token',
        { refreshToken: late.refreshToken },
        { headers: { 'Idempotency-Key': 'late-password-change-rotation' } }
      )
    ).status,
    401
  );
  assert.equal(
    (await api.post('/auth/token', { refreshToken: renewed.refreshToken }, operation)).status,
    401
  );
  const fresh = await loginModern({ ...user, password: 'replacement-long-password' });
  const current = await api.post(
    '/auth/token',
    { refreshToken: fresh.refreshToken },
    { headers: { 'Idempotency-Key': 'after-password-change-rotation' } }
  );
  assert.equal(current.status, 200);
  assert.equal(jwt.decode(current.body.token).version, 1);
  assert.equal((await api.get('/api/me', { token: current.body.token })).status, 200);
  const listing = await api.get('/api/sessions', { token: current.body.token });
  assert.deepEqual(
    listing.body.map((row) => row.id),
    [fresh.sessionId]
  );
});

test('compatibility refresh rechecks credentials after request authentication', async () => {
  const user = await signUp(api);
  const before = await api.store.findById('users', user.user._id);
  const token = user.token;
  const { upgradeSession } = require('../lib/sessions');
  const req = {
    user: jwt.decode(token),
    token,
    get: (header) =>
      ({ 'X-Session-Protocol': '2', 'Idempotency-Key': 'late-upgrade-operation' })[header],
  };
  await api.store.update('users', { id: before.id }, { credentials_version: 1 });
  const current = await api.store.findById('users', before.id);
  for (const supplied of [before, current]) {
    await assert.rejects(upgradeSession(supplied, req), (error) => error.status === 401);
    await assert.rejects(
      upgradeSession(supplied, { ...req, get: () => undefined }),
      (error) => error.status === 401
    );
  }
  assert.equal(await api.store.count('sessions', { account_id: before.id }), 1);
});

test('device listings and revocation are account-scoped and exclude credentials', async () => {
  const user = await signUp(api);
  const other = await signUp(api);
  const session = await loginModern(user);
  const listing = await api.get('/api/sessions', { token: session.token });
  assert.ok(listing.body.some((row) => row.current && row.device_name === 'Test phone'));
  assert.ok(!JSON.stringify(listing.body).includes('refresh'));
  await api.del(`/api/sessions/${session.sessionId}`, { token: other.token });
  assert.equal((await api.get('/api/me', { token: session.token })).status, 200);
  await api.del(`/api/sessions/${session.sessionId}`, { token: user.token });
  assert.equal((await api.get('/api/me', { token: session.token })).status, 401);
});

test('admin authorization checks current privileges rather than token claims', async () => {
  const admin = await signUp(api, { email: 'admin@exerly.test' });
  assert.equal((await api.get('/api/admin/users', { token: admin.token })).status, 200);
  await api.store.update('users', { email: admin.email }, { is_admin: false });
  assert.equal((await api.get('/api/admin/users', { token: admin.token })).status, 403);
});

test('compatibility refresh is bounded per account and read-only session checks create no sessions', async () => {
  const user = await signUp(api);
  const owned = { account_id: user.user._id };
  for (let i = 0; i < 5; i++)
    assert.equal((await api.get('/api/me', { token: user.token })).status, 200);
  assert.equal(await api.store.count('sessions', owned), 1);
  for (let i = 0; i < 60; i++)
    assert.equal((await api.post('/auth/refresh', {}, { token: user.token })).status, 200);
  assert.equal((await api.post('/auth/refresh', {}, { token: user.token })).status, 429);
  assert.equal(await api.store.count('sessions', owned), 61);
  const other = await signUp(api);
  assert.equal((await api.post('/auth/refresh', {}, { token: other.token })).status, 200);
  assert.equal((await api.get('/api/me', { token: user.token })).status, 200);
});

test('email-only legacy credentials upgrade once under concurrent replay without storing usable credentials', async () => {
  const user = await signUp(api);
  const token = jwt.sign({ email: user.email, is_admin: false }, process.env.JWT_SECRET, {
    expiresIn: '1h',
  });
  const options = {
    token,
    headers: { 'X-Session-Protocol': '2', 'Idempotency-Key': 'persisted-legacy-upgrade' },
  };
  const results = await Promise.all(
    Array.from({ length: 4 }, () => api.post('/auth/refresh', {}, options))
  );
  const first = results[0].body;
  for (const result of results) {
    assert.equal(result.status, 200);
    assert.equal(result.body.sessionId, first.sessionId);
    assert.equal(result.body.refreshToken, first.refreshToken);
    assert.equal(jwt.decode(result.body.token).sub, user.user._id);
    assert.equal(jwt.decode(result.body.token).exp - jwt.decode(result.body.token).iat, 900);
  }
  assert.equal(await api.store.count('sessions', { account_id: user.user._id }), 2);
  for (const collection of ['sessions', 'operations']) {
    const stored = await api.store.find(collection, { account_id: user.user._id });
    assert.ok(
      !JSON.stringify(stored).includes(first.refreshToken),
      `${collection} must not retain usable refresh credentials`
    );
    assert.ok(
      !JSON.stringify(stored).includes(token),
      `${collection} must not retain the legacy bearer token`
    );
  }
  const other = await signUp(api);
  const different = await api.post('/auth/refresh', {}, { ...options, token: other.token });
  assert.equal(different.status, 200);
  assert.notEqual(different.body.sessionId, first.sessionId);
  assert.equal(jwt.decode(different.body.token).sub, other.user._id);
});

test('a saved compatibility upgrade cannot revive a revoked session', async () => {
  const user = await signUp(api);
  const options = {
    token: user.token,
    headers: { 'X-Session-Protocol': '2', 'Idempotency-Key': 'revoked-legacy-upgrade' },
  };
  const upgraded = await api.post('/auth/refresh', {}, options);
  assert.equal(upgraded.status, 200);
  assert.equal(
    (await api.del(`/api/sessions/${upgraded.body.sessionId}`, { token: user.token })).status,
    200
  );
  assert.equal((await api.post('/auth/refresh', {}, options)).status, 401);
  assert.equal(await api.store.count('sessions', { account_id: user.user._id }), 2);
});

test('an acknowledgement from the previous server recovers its original session and removes stored credentials', async () => {
  const user = await signUp(api);
  const priorSession = await loginModern(user);
  const operation = 'before-server-upgrade-response';
  const fingerprint = createHash('sha256')
    .update(canonicalJSON({ method: 'POST', path: '/auth/refresh', body: {}, revision: null }))
    .digest('hex');
  await api.store.insert('operations', {
    account_id: user.user._id,
    key: operation,
    fingerprint,
    status: 200,
    response: priorSession,
    created_at: new Date(),
  });
  const options = {
    token: user.token,
    headers: { 'X-Session-Protocol': '2', 'Idempotency-Key': operation },
  };
  for (let attempt = 0; attempt < 2; attempt++) {
    const result = await api.post('/auth/refresh', {}, options);
    assert.equal(result.status, 200);
    assert.equal(result.body.sessionId, priorSession.sessionId);
    assert.equal(result.body.refreshToken, priorSession.refreshToken);
  }
  assert.equal(await api.store.count('sessions', { account_id: user.user._id }), 2);
  const saved = await api.store.findOne('operations', {
    account_id: user.user._id,
    key: operation,
  });
  assert.deepEqual(saved.response, { sessionId: priorSession.sessionId, session_upgrade: true });
  assert.equal((await api.post('/auth/refresh', { different: true }, options)).status, 409);
});
