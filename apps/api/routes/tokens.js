// Personal access tokens, managed only from a signed-in session (lib/auth.js
// refuses tokens here). The secret is returned once; only its hash is kept.

const express = require('express');
const { createHash, randomBytes } = require('node:crypto');

const store = require('../data');
const { asyncHandler, badRequest, conflict, notFound } = require('../lib/errors');
const { authenticate } = require('../lib/auth');
const v = require('../lib/validate');
const { appendAudit } = require('../lib/documents');

const router = express.Router();
router.use(authenticate);

const SCOPES = ['read', 'propose', 'write'];
const MAX_ACTIVE = 20;
const you = { kind: 'builtIn', name: 'You' };

function present(row) {
  return {
    id: row.id,
    name: row.name,
    prefix: row.prefix,
    scopes: row.scopes,
    created_at: row.created_at,
    last_used_at: row.last_used_at ?? null,
    expires_at: row.expires_at ?? null,
  };
}

const active = (row) => !row.revoked_at && (!row.expires_at || row.expires_at > new Date());

router.get(
  '/',
  asyncHandler(async (req, res) => {
    const rows = await store.find('personal_access_tokens', {
      account_id: req.account.id,
      revoked_at: null,
    });
    res.json(rows.filter(active).map(present));
  })
);

router.post(
  '/',
  asyncHandler(async (req, res) => {
    const name = v.str(req.body?.name, 'name', { max: 60 });
    const requested = req.body?.scopes;
    if (
      !Array.isArray(requested) ||
      requested.length === 0 ||
      !requested.every((s) => SCOPES.includes(s))
    ) {
      throw badRequest(`scopes must be a non-empty list of ${SCOPES.join(', ')}`);
    }
    // Every token can read; scopes are kept in a fixed order.
    const scopes = SCOPES.filter((s) => s === 'read' || requested.includes(s));
    const days =
      req.body?.expires_in_days == null
        ? null
        : v.int(req.body.expires_in_days, 'expires_in_days', { min: 1, max: 3650 });
    const existing = await store.find('personal_access_tokens', {
      account_id: req.account.id,
      revoked_at: null,
    });
    if (existing.filter(active).length >= MAX_ACTIVE) {
      throw conflict(`An account can have ${MAX_ACTIVE} active tokens. Revoke one first.`);
    }
    const token = `exr_${randomBytes(32).toString('base64url')}`;
    const row = await store.insert('personal_access_tokens', {
      account_id: req.account.id,
      name,
      token_hash: createHash('sha256').update(token).digest('hex'),
      prefix: token.slice(0, 12),
      scopes,
      created_at: new Date(),
      expires_at: days ? new Date(Date.now() + days * 86_400_000) : null,
    });
    await appendAudit(req.account, {
      action: 'tokenCreated',
      actor: you,
      targets: [{ kind: 'token', id: row.id }],
      note: name,
    });
    res.status(201).json({ ...present(row), token });
  })
);

router.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    const row = await store.findOne('personal_access_tokens', {
      id: req.params.id,
      account_id: req.account.id,
    });
    if (!row || row.revoked_at) throw notFound('Token not found');
    await store.update('personal_access_tokens', { id: row.id }, { revoked_at: new Date() });
    await appendAudit(req.account, {
      action: 'tokenRevoked',
      actor: you,
      targets: [{ kind: 'token', id: row.id }],
      note: row.name,
    });
    res.json({ revoked: true });
  })
);

module.exports = router;
