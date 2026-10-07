// /v1/webhooks: the person's own endpoints, told when their change feed moves
// on (lib/webhooks.js). A signed-in session manages all of the account's; a
// personal access token sees only those it created, and they stop when it is
// revoked. The signing secret is returned once.

const express = require('express');

const store = require('../data');
const { asyncHandler, conflict, notFound } = require('../lib/errors');
const { authenticate } = require('../lib/auth');
const webhooks = require('../lib/webhooks');

const router = express.Router();
router.use(authenticate);

const MAX_PER_ACCOUNT = 5;

function present(row) {
  return {
    id: row.id,
    url: row.url,
    created_at: row.created_at,
    created_by_token: row.token_id ?? null,
    delivered_sequence: row.delivered_sequence ?? 0,
    last_delivery_at: row.last_delivery_at ?? null,
    failures: row.failures ?? 0,
    last_error: row.last_error ?? null,
    disabled_at: row.disabled_at ?? null,
  };
}

const mine = (req) => ({
  account_id: req.account.id,
  ...(req.pat ? { token_id: req.pat.id } : {}),
});

router.get(
  '/',
  asyncHandler(async (req, res) => {
    res.json((await store.find('webhooks', mine(req))).map(present));
  })
);

router.post(
  '/',
  asyncHandler(async (req, res) => {
    const url = webhooks.checkURL(req.body?.url);
    await webhooks.checkResolves(url);
    const existing = await store.find('webhooks', { account_id: req.account.id });
    if (existing.length >= MAX_PER_ACCOUNT) {
      throw conflict(`An account can have at most ${MAX_PER_ACCOUNT} webhooks. Delete one first.`);
    }
    // Changes from now on, not the account's whole history.
    const cursor = await store.findOne('sync_cursors', { account_id: req.account.id });
    const secret = webhooks.newSecret();
    const now = new Date();
    const row = await store.insert('webhooks', {
      account_id: req.account.id,
      token_id: req.pat?.id ?? null,
      url,
      secret,
      created_at: now,
      delivered_sequence: cursor?.sequence ?? 0,
      next_attempt_at: now,
      failures: 0,
    });
    res.status(201).json({ ...present(row), secret });
  })
);

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function owned(req) {
  if (!UUID_RE.test(req.params.id)) throw notFound('No webhook has that ID');
  const row = await store.findOne('webhooks', { ...mine(req), id: req.params.id.toLowerCase() });
  if (!row) throw notFound('No webhook has that ID');
  return row;
}

// After the endpoint is fixed: deliver again from where it left off.
router.post(
  '/:id/enable',
  asyncHandler(async (req, res) => {
    const row = await owned(req);
    const updated = await store.update(
      'webhooks',
      { id: row.id },
      { disabled_at: null, failures: 0, last_error: null, next_attempt_at: new Date() }
    );
    res.json(present(updated ?? row));
  })
);

router.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    const row = await owned(req);
    await store.removeOne('webhooks', { id: row.id });
    res.status(204).end();
  })
);

module.exports = router;
