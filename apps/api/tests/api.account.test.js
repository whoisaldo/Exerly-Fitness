// Account deletion and the data export, checked against every table.

const test = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID, generateKeyPairSync, randomBytes } = require('node:crypto');
const jwt = require('jsonwebtoken');
const { startServer, signUp } = require('./helpers/server');
const { collections, types } = require('../data/schema');
const { OWNERSHIP, ownerFilters } = require('../lib/ownership');
const apple = require('../lib/apple');

let api;
test.before(async () => {
  api = await startServer();
});
test.after(async () => {
  await api.close();
});

const sample = {
  [types.str]: () => `synthetic-${randomUUID()}`,
  [types.num]: 1,
  [types.bool]: false,
  [types.date]: new Date('2026-10-06T12:00:00Z'),
  [types.json]: { synthetic: true },
};

/** One synthetic row in every owned table, for each owner key. */
async function seedEverything(user) {
  for (const [collection, rule] of Object.entries(OWNERSHIP)) {
    if (collection === 'users') continue;
    for (const filter of ownerFilters(collection, user)) {
      const row = {};
      for (const [field, type] of Object.entries(collections[collection].fields)) {
        row[field] = typeof sample[type] === 'function' ? sample[type]() : sample[type];
      }
      if (collection === 'account_identities') {
        Object.assign(row, { provider: 'apple', subject: randomUUID(), account_id: user.id });
      }
      if (collection === 'sync_changes') row.sequence = Math.random();
      try {
        await api.store.insert(collection, { ...row, ...filter });
      } catch (error) {
        // A one-per-account row (a sync cursor, say) may already exist.
        if (error.code !== '23505') throw error;
      }
    }
    assert.ok(rule.keys.length === 0 || ownerFilters(collection, user).length > 0, collection);
  }
}

async function countOwned(user) {
  const counts = {};
  for (const collection of Object.keys(OWNERSHIP)) {
    let total = 0;
    for (const filter of ownerFilters(collection, user))
      total += await api.store.count(collection, filter);
    counts[collection] = total;
  }
  return counts;
}

test('every table in the schema has an ownership rule', () => {
  assert.deepEqual(Object.keys(OWNERSHIP).sort(), Object.keys(collections).sort());
  for (const [collection, rule] of Object.entries(OWNERSHIP)) {
    for (const key of rule.keys) {
      assert.ok(key === 'id' || key in collections[collection].fields, `${collection}.${key}`);
    }
  }
});

test('the export holds every exportable table, only the owner rows, and no secrets', async () => {
  const owner = await signUp(api);
  const other = await signUp(api);
  await api.post('/api/food', { name: 'Exported oats', calories: 300 }, { token: owner.token });
  await api.post('/api/food', { name: 'Not mine', calories: 1 }, { token: other.token });
  await api.post('/api/weight', { weight: 80.4 }, { token: owner.token });

  const res = await api.get('/api/export', { token: owner.token });
  assert.equal(res.status, 200);
  assert.match(res.headers.get('content-disposition'), /attachment; filename="exerly-export-/);
  assert.equal(res.body.version, 3);
  assert.equal(res.body.account.email, owner.email);
  for (const [collection, rule] of Object.entries(OWNERSHIP)) {
    const exported = rule.export !== false && rule.keys.length > 0;
    if (rule.single) assert.ok(rule.single in res.body, rule.single);
    else assert.equal(Array.isArray(res.body[collection]), exported, collection);
  }
  assert.deepEqual(
    res.body.food.map((f) => f.name),
    ['Exported oats']
  );
  assert.equal(res.body.weights[0].weight_kg, 80.4);
  const text = JSON.stringify(res.body);
  for (const secret of ['"hash"', 'refresh_hash', 'Not mine', other.email]) {
    assert.ok(!text.includes(secret), `export contains ${secret}`);
  }
});

test('deleting an account removes every row it owns and nothing else', async () => {
  const doomed = await signUp(api);
  const survivor = await signUp(api);
  await api.post('/api/food', { name: 'Gone soon', calories: 200 }, { token: doomed.token });
  await api.post(
    '/api/water',
    { deltaMl: 250 },
    { token: doomed.token, headers: { 'Idempotency-Key': randomUUID() } }
  );
  const doomedUser = { id: doomed.user._id, email: doomed.email };
  const survivorUser = { id: survivor.user._id, email: survivor.email };
  await seedEverything(doomedUser);
  await seedEverything(survivorUser);
  const survivorBefore = await countOwned(survivorUser);

  assert.equal(
    (await api.del('/api/account', { token: doomed.token })).status,
    400,
    'needs confirmation'
  );
  const deleted = await api.del('/api/account', { token: doomed.token, body: { confirm: true } });
  assert.equal(deleted.status, 200);
  assert.equal(deleted.body.deleted, true);

  const after = await countOwned(doomedUser);
  for (const [collection, count] of Object.entries(after))
    assert.equal(count, 0, `${collection} kept ${count}`);
  assert.equal(await api.store.count('users', { email: doomed.email }), 0);
  assert.deepEqual(await countOwned(survivorUser), survivorBefore);

  assert.equal((await api.get('/api/me', { token: doomed.token })).status, 401);
  const again = await api.post('/signup', {
    name: 'Back again',
    email: doomed.email,
    password: 'correct-horse-battery',
  });
  assert.equal(again.status, 201);
});

test('an Apple account is revoked with Apple before anything is deleted', async () => {
  const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  apple.publicKey = async () => publicKey;
  const nonce = randomBytes(16).toString('hex');
  const identityToken = jwt.sign(
    {
      iss: 'https://appleid.apple.com',
      aud: 'com.exerly.fitness',
      sub: '001234.delete.0001',
      nonce: apple.sha256(nonce),
    },
    privateKey,
    { algorithm: 'RS256', keyid: 'k', expiresIn: '10m' }
  );
  const signedIn = await api.post('/auth/apple', { identityToken, nonce });
  assert.equal(signedIn.status, 201);
  const token = signedIn.body.token;
  const remove = (body) => api.del('/api/account', { token, body });

  const calls = [];
  const original = {
    configured: apple.revocationConfigured,
    revoke: apple.revokeAuthorizationCode,
  };
  apple.revocationConfigured = () => true;
  apple.revokeAuthorizationCode = async (code) => {
    calls.push(code);
    if (code === 'bad-code') throw new Error('rejected');
  };
  try {
    const missing = await remove({ confirm: true });
    assert.equal(missing.status, 400);
    assert.equal(missing.body.details.code, 'apple_reauthorization_required');

    const failed = await remove({ confirm: true, appleAuthorizationCode: 'bad-code' });
    assert.equal(failed.status, 502);
    assert.equal(
      await api.store.count('users', { id: signedIn.body.user._id }),
      1,
      'nothing deleted'
    );

    const done = await remove({ confirm: true, appleAuthorizationCode: 'fresh-code' });
    assert.equal(done.status, 200);
    assert.equal(done.body.apple_revoked, true);
    assert.deepEqual(calls, ['bad-code', 'fresh-code']);
    assert.equal(await api.store.count('account_identities', { subject: '001234.delete.0001' }), 0);
  } finally {
    apple.revocationConfigured = original.configured;
    apple.revokeAuthorizationCode = original.revoke;
  }
});
