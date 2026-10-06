// v1 document sync: revisions, conflicts, idempotency, tombstones, the change
// feed and isolation.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const { startServer, signUp } = require('./helpers/server');

let api;
test.before(async () => {
  api = await startServer();
});
test.after(async () => {
  await api.close();
});

const sessionID = () => randomUUID().toUpperCase();
const session = (id, notes = '') => ({
  id,
  name: 'Synthetic push day',
  startedAt: '2026-10-06T18:00:00.000Z',
  timeZoneID: 'America/New_York',
  notes,
  exercises: [],
});
const key = () => ({ 'Idempotency-Key': randomUUID() });
const put = (token, id, payload, base_revision, headers = key()) =>
  api.put(`/v1/documents/workout_session/${id}`, { payload, base_revision }, { token, headers });

test('documents get server revisions and stale writes conflict with the current version', async () => {
  const { token } = await signUp(api);
  const id = sessionID();
  const created = await put(token, id, session(id), 0);
  assert.equal(created.status, 201, JSON.stringify(created.body));
  assert.equal(created.body.revision, 1);
  assert.equal(created.body.kind, 'workout_session');
  assert.equal(created.body.id, id);

  const updated = await put(token, id, session(id, 'second'), 1);
  assert.equal(updated.status, 200);
  assert.equal(updated.body.revision, 2);

  const stale = await put(token, id, session(id, 'stale'), 1);
  assert.equal(stale.status, 409);
  assert.equal(stale.body.details.document.revision, 2);
  assert.equal(stale.body.details.document.payload.notes, 'second');

  const read = await api.get(`/v1/documents/workout_session/${id}`, { token });
  assert.equal(read.status, 200);
  assert.deepEqual(read.body.payload, session(id, 'second'));
  assert.equal(read.body.deleted, false);

  const recreate = await put(token, id, session(id), 0);
  assert.equal(recreate.status, 409, 'creating over an existing document conflicts');
});

test('a retried push with the same key applies once', async () => {
  const { token } = await signUp(api);
  const id = sessionID();
  const headers = key();
  const results = await Promise.all(
    Array.from({ length: 5 }, () => put(token, id, session(id), 0, headers))
  );
  assert.ok(
    results.every((r) => r.status === 201),
    JSON.stringify(results.map((r) => r.status))
  );
  for (const r of results) assert.deepEqual(r.body, results[0].body);
  const read = await api.get(`/v1/documents/workout_session/${id}`, { token });
  assert.equal(read.body.revision, 1);
});

test('deletion leaves a tombstone that reaches other devices and can be restored', async () => {
  const { token } = await signUp(api);
  const id = sessionID();
  await put(token, id, session(id), 0);
  const stale = await api.del(`/v1/documents/workout_session/${id}?base_revision=0`, {
    token,
    headers: key(),
  });
  assert.equal(stale.status, 409);
  const deleted = await api.del(`/v1/documents/workout_session/${id}?base_revision=1`, {
    token,
    headers: key(),
  });
  assert.equal(deleted.status, 200);
  assert.equal(deleted.body.revision, 2);
  assert.equal(deleted.body.deleted, true);

  const read = await api.get(`/v1/documents/workout_session/${id}`, { token });
  assert.equal(read.body.deleted, true);
  assert.equal(read.body.payload, null);

  const restored = await put(token, id, session(id, 'restored'), 2);
  assert.equal(restored.status, 200);
  assert.equal(restored.body.revision, 3);
  assert.equal(
    (
      await api.del(`/v1/documents/workout_session/${sessionID()}?base_revision=0`, {
        token,
        headers: key(),
      })
    ).status,
    404
  );
});

test('the change feed lists document changes in order and pages past legacy kinds', async () => {
  const { token } = await signUp(api);
  const a = sessionID();
  const b = sessionID();
  await put(token, a, session(a), 0);
  await api.post('/api/water', { deltaMl: 250 }, { token, headers: key() });
  await put(token, b, session(b), 0);
  await api.post('/api/water', { deltaMl: 250 }, { token, headers: key() });
  await put(token, a, session(a, 'edited'), 1);
  await api.del(`/v1/documents/workout_session/${b}?base_revision=1`, { token, headers: key() });
  await api.post('/api/water', { deltaMl: 250 }, { token, headers: key() });

  const all = (await api.get('/v1/changes?after=0', { token })).body;
  assert.deepEqual(
    all.changes.map((c) => [c.id, c.revision, c.deleted]),
    [
      [a, 1, false],
      [b, 1, false],
      [a, 2, false],
      [b, 2, true],
    ]
  );
  assert.equal(all.changes[2].payload.notes, 'edited');
  assert.equal(all.changes[3].payload, null);
  assert.equal(all.cursor, 7, 'the cursor passes the trailing legacy change');
  assert.equal(all.has_more, false);

  const pages = [];
  let cursor = 0;
  for (let i = 0; i < 10; i++) {
    const page = (await api.get(`/v1/changes?after=${cursor}&limit=2`, { token })).body;
    pages.push(...page.changes.map((c) => `${c.id}:${c.revision}`));
    cursor = page.cursor;
    if (!page.has_more) break;
  }
  assert.deepEqual(
    pages,
    all.changes.map((c) => `${c.id}:${c.revision}`)
  );
  assert.equal(cursor, 7);
});

test('documents are private to their account', async () => {
  const owner = await signUp(api);
  const intruder = await signUp(api);
  const id = sessionID();
  await put(owner.token, id, session(id, 'private'), 0);
  assert.equal(
    (await api.get(`/v1/documents/workout_session/${id}`, { token: intruder.token })).status,
    404
  );
  assert.equal(
    (
      await api.del(`/v1/documents/workout_session/${id}?base_revision=1`, {
        token: intruder.token,
        headers: key(),
      })
    ).status,
    404
  );
  // The same ID in another account is a separate document.
  const own = await put(intruder.token, id, session(id, 'mine'), 0);
  assert.equal(own.status, 201);
  assert.equal(
    (await api.get('/v1/changes?after=0', { token: intruder.token })).body.changes.length,
    1
  );
  const ownerCopy = await api.get(`/v1/documents/workout_session/${id}`, { token: owner.token });
  assert.equal(ownerCopy.body.payload.notes, 'private');
});

test('rejects unknown kinds, bad ids, mismatched payloads and missing base revisions', async () => {
  const { token } = await signUp(api);
  const id = sessionID();
  const cases = [
    ['/v1/documents/food_photo/' + id, { payload: { id }, base_revision: 0 }],
    [
      '/v1/documents/workout_session/has%20space',
      { payload: { id: 'has space' }, base_revision: 0 },
    ],
    [`/v1/documents/workout_session/${id}`, { payload: { id: sessionID() }, base_revision: 0 }],
    [`/v1/documents/workout_session/${id}`, { payload: [id], base_revision: 0 }],
    [`/v1/documents/workout_session/${id}`, { payload: session(id) }],
    [`/v1/documents/workout_session/${id}`, { payload: session(id), base_revision: -1 }],
  ];
  for (const [path, body] of cases) {
    const res = await api.put(path, body, { token, headers: key() });
    assert.equal(res.status, 400, `${path} ${JSON.stringify(body).slice(0, 60)} -> ${res.status}`);
  }
  assert.equal((await api.get('/v1/changes?after=0', { token })).body.changes.length, 0);
});

test('custom exercises sync as documents and appear in the export and deletion', async () => {
  const user = await signUp(api);
  const id = `custom-${randomUUID().toLowerCase()}`;
  const exercise = { id, name: 'Zercher Squat', metric: 'weightReps' };
  const res = await api.put(
    `/v1/documents/custom_exercise/${id}`,
    { payload: exercise, base_revision: 0 },
    { token: user.token, headers: key() }
  );
  assert.equal(res.status, 201);
  const exported = (await api.get('/api/export', { token: user.token })).body;
  assert.equal(exported.documents.length, 1);
  assert.deepEqual(exported.documents[0].payload, exercise);
  await api.del('/api/account', { token: user.token, body: { confirm: true } });
  assert.equal(await api.store.count('documents', { account_id: user.user._id }), 0);
});

test('proposals and audit events sync, and audit events never change', async () => {
  const { token } = await signUp(api);
  const proposalID = randomUUID().toUpperCase();
  const proposal = {
    id: proposalID,
    title: 'Did you mean 150 kg?',
    summary: 'Ten times your history.',
    falsifier: 'You lifted 1500 kg.',
    status: 'pending',
    confidence: 'high',
    author: { kind: 'mcp', name: 'Synthetic agent' },
    changes: [{ kind: 'workout_session', id: 'X', after: { id: 'X', notes: 'Fixed' } }],
    evidence: [],
    createdAt: '2026-10-06T18:00:00.000Z',
  };
  const filed = await api.put(
    `/v1/documents/proposal/${proposalID}`,
    { payload: proposal, base_revision: 0 },
    { token, headers: key() }
  );
  assert.equal(filed.status, 201, JSON.stringify(filed.body));
  const decided = await api.put(
    `/v1/documents/proposal/${proposalID}`,
    { payload: { ...proposal, status: 'accepted' }, base_revision: 1 },
    { token, headers: key() }
  );
  assert.equal(decided.status, 200);

  const missingFalsifier = await api.put(
    `/v1/documents/proposal/${randomUUID().toUpperCase()}`,
    { payload: { ...proposal, id: undefined, falsifier: ' ' }, base_revision: 0 },
    { token, headers: key() }
  );
  assert.equal(missingFalsifier.status, 400);

  const eventID = randomUUID().toUpperCase();
  const event = {
    id: eventID,
    action: 'proposalAccepted',
    at: '2026-10-06T18:05:00.000Z',
    actor: { kind: 'builtIn', name: 'You' },
    targets: [{ kind: 'workout_session', id: 'X' }],
  };
  const path = `/v1/documents/audit_event/${eventID}`;
  assert.equal(
    (await api.put(path, { payload: event, base_revision: 0 }, { token, headers: key() })).status,
    201
  );
  // Re-sending the same event is harmless; changing or deleting it is refused.
  assert.equal(
    (await api.put(path, { payload: event, base_revision: 1 }, { token, headers: key() })).status,
    200
  );
  assert.equal(
    (
      await api.put(
        path,
        { payload: { ...event, action: 'proposalRejected' }, base_revision: 1 },
        { token, headers: key() }
      )
    ).status,
    400
  );
  assert.equal((await api.del(`${path}?base_revision=1`, { token, headers: key() })).status, 400);
  const changes = (await api.get('/v1/changes?after=0', { token })).body.changes;
  assert.deepEqual(
    changes.map((c) => `${c.kind}:${c.revision}`),
    ['proposal:1', 'proposal:2', 'audit_event:1']
  );
});

test('a UUID document ID is one document whatever its letter case', async () => {
  const { token, user } = await signUp(api);
  const upper = randomUUID().toUpperCase();
  const lower = upper.toLowerCase();
  const session = (id, notes) => ({
    id,
    name: '',
    notes,
    startedAt: '2026-10-06T18:00:00.000Z',
    timeZoneID: 'UTC',
    exercises: [],
  });
  const first = await api.put(
    `/v1/documents/workout_session/${lower}`,
    { payload: session(lower, 'first'), base_revision: 0 },
    { token, headers: key() }
  );
  assert.equal(first.status, 201, JSON.stringify(first.body));
  assert.equal(first.body.id, upper);
  const second = await api.put(
    `/v1/documents/workout_session/${upper}`,
    { payload: session(upper, 'second'), base_revision: 1 },
    { token, headers: key() }
  );
  assert.equal(second.status, 200);
  assert.equal(second.body.revision, 2);
  const read = await api.get(`/v1/documents/workout_session/${lower}`, { token });
  assert.equal(read.body.payload.id, upper);
  assert.equal(read.body.payload.notes, 'second');
  assert.equal(
    await api.store.count('documents', { account_id: user._id, kind: 'workout_session' }),
    1
  );
  const feed = (await api.get('/v1/changes?after=0', { token })).body.changes;
  assert.ok(feed.every((c) => c.id === upper && c.payload.id === upper));

  const proposalID = randomUUID();
  const filed = await api.put(
    `/v1/documents/proposal/${proposalID}`,
    {
      payload: {
        id: proposalID,
        createdAt: '2026-10-06T18:30:00.000Z',
        author: { kind: 'builtIn', name: 'Exerly' },
        title: 'Fix',
        summary: '',
        changes: [{ kind: 'workout_session', id: lower, after: session(lower, 'x') }],
        evidence: [
          {
            claim: 'c',
            level: 'anecdote',
            caveats: [],
            dataRefs: [{ kind: 'workout_session', id: lower }],
          },
        ],
        confidence: 'low',
        falsifier: 'f',
        status: 'pending',
      },
      base_revision: 0,
    },
    { token, headers: key() }
  );
  assert.equal(filed.status, 201, JSON.stringify(filed.body));
  const stored = (await api.get(`/v1/documents/proposal/${proposalID}`, { token })).body.payload;
  assert.equal(stored.id, proposalID.toUpperCase());
  assert.equal(stored.changes[0].id, upper);
  assert.equal(stored.evidence[0].dataRefs[0].id, upper);
});

test('the migration uppercases UUID document IDs and refuses to merge twins', async () => {
  const { user } = await signUp(api);
  const sql = fs.readFileSync(
    path.join(__dirname, '../db/migrations/0005_canonical_document_ids.up.sql'),
    'utf8'
  );
  const now = new Date();
  const insertDocument = (id) =>
    api.store.insert('documents', {
      account_id: user._id,
      kind: 'workout_session',
      document_id: id,
      revision: 1,
      payload: { id },
      deleted_at: null,
      created_at: now,
      updated_at: now,
    });
  const insertChange = (kind, id, sequence) =>
    api.store.insert('sync_changes', {
      account_id: user._id,
      sequence,
      kind,
      entity_id: id,
      server_id: id,
      revision: 1,
      deleted: false,
      payload: { payload: { id } },
      created_at: now,
    });
  const lower = randomUUID();
  const legacy = randomUUID();
  await insertDocument(lower);
  await insertChange('workout_session', lower, 1001);
  await insertChange('water', legacy, 1002);

  await api.store.query(sql);
  const rows = await api.store.find('documents', { account_id: user._id });
  assert.deepEqual(
    rows.map((r) => r.document_id),
    [lower.toUpperCase()]
  );
  const changes = await api.store.find('sync_changes', { account_id: user._id });
  assert.deepEqual(changes.map((c) => c.entity_id).sort(), [lower.toUpperCase(), legacy].sort());

  const twin = randomUUID();
  await insertDocument(twin);
  await insertDocument(twin.toUpperCase());
  await assert.rejects(api.store.query(sql), /duplicate key|unique/i);
});
