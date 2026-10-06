// v1 document sync for ExerlyCore entities. See docs/design/003-document-sync.md.
//
// Every write runs inside the mutation transaction (lib/mutations.js), so the
// document, its change-feed entry and the idempotency receipt commit together.

const express = require('express');

const store = require('../data');
const sync = require('../lib/sync');
const { asyncHandler, badRequest, conflict, notFound } = require('../lib/errors');
const { authenticate } = require('../lib/auth');
const v = require('../lib/validate');

const router = express.Router();
router.use(authenticate);

// Kinds a client may sync, with the fields their payloads must carry.
const KINDS = {
  workout_session: (p) => typeof p.startedAt === 'string' && Array.isArray(p.exercises),
  custom_exercise: (p) => typeof p.name === 'string' && typeof p.metric === 'string',
};
const ID_RE = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/;

function readKind(value) {
  if (!Object.prototype.hasOwnProperty.call(KINDS, value))
    throw badRequest(`Unknown document kind ${value}`);
  return value;
}

function readID(value) {
  if (!ID_RE.test(value))
    throw badRequest(
      'Document IDs are 1 to 128 letters, digits, dots, colons, underscores or hyphens'
    );
  return value;
}

function readBase(value) {
  if (value == null || value === '') throw badRequest('base_revision is required; use 0 to create');
  return v.int(value, 'base_revision', { min: 0 });
}

function readPayload(kind, id, payload) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    throw badRequest('payload must be an object');
  }
  if (payload.id !== id) throw badRequest('payload.id must match the document ID');
  if (!KINDS[kind](payload)) throw badRequest(`payload is not a valid ${kind}`);
  return payload;
}

function present(row) {
  return {
    kind: row.kind,
    id: row.document_id,
    revision: row.revision,
    deleted: !!row.deleted_at,
    payload: row.payload ?? null,
    updated_at: row.updated_at,
  };
}

function acknowledge(row) {
  const { payload: _payload, ...rest } = present(row);
  return rest;
}

async function current(req, kind, id) {
  return store.findOne('documents', { account_id: req.account.id, kind, document_id: id });
}

async function record(req, row) {
  await sync.change(req.account, row.kind, {
    id: row.document_id,
    client_id: row.document_id,
    revision: row.revision,
    deleted_at: row.deleted_at,
    payload: row.payload ?? null,
    updated_at: row.updated_at,
  });
}

router.get(
  '/documents/:kind/:id',
  asyncHandler(async (req, res) => {
    const row = await current(req, readKind(req.params.kind), readID(req.params.id));
    if (!row) throw notFound('Document not found');
    res.json(present(row));
  })
);

router.put(
  '/documents/:kind/:id',
  asyncHandler(async (req, res) => {
    const kind = readKind(req.params.kind);
    const id = readID(req.params.id);
    const base = readBase(req.body?.base_revision);
    const payload = readPayload(kind, id, req.body?.payload);
    const existing = await current(req, kind, id);
    if (base !== (existing?.revision ?? 0)) {
      throw conflict('This document changed on another device. Merge and retry.', {
        document: existing ? present(existing) : null,
      });
    }
    const now = new Date();
    const revision = base + 1;
    const row = existing
      ? await store.update(
          'documents',
          { id: existing.id },
          { revision, payload, deleted_at: null, updated_at: now }
        )
      : await store.insert('documents', {
          account_id: req.account.id,
          kind,
          document_id: id,
          revision,
          payload,
          deleted_at: null,
          created_at: now,
          updated_at: now,
        });
    await record(req, row);
    res.status(existing ? 200 : 201).json(acknowledge(row));
  })
);

router.delete(
  '/documents/:kind/:id',
  asyncHandler(async (req, res) => {
    const kind = readKind(req.params.kind);
    const id = readID(req.params.id);
    const base = readBase(req.query.base_revision ?? req.body?.base_revision);
    const existing = await current(req, kind, id);
    if (!existing) throw notFound('Document not found');
    if (base !== existing.revision) {
      throw conflict('This document changed on another device. Merge and retry.', {
        document: present(existing),
      });
    }
    if (existing.deleted_at) return res.json(acknowledge(existing));
    const now = new Date();
    const row = await store.update(
      'documents',
      { id: existing.id },
      { revision: base + 1, payload: null, deleted_at: now, updated_at: now }
    );
    await record(req, row);
    res.json(acknowledge(row));
  })
);

// Document changes after a cursor. The cursor counts every entry in the
// account's feed, so it moves past legacy kinds this API doesn't return.
router.get(
  '/changes',
  asyncHandler(async (req, res) => {
    const after = v.int(req.query.after ?? 0, 'after', { min: 0 });
    const limit = v.int(req.query.limit ?? 500, 'limit', { min: 1, max: 1000 });
    const scanned = await store.find(
      'sync_changes',
      { account_id: req.account.id, sequence: { gt: after } },
      { sort: { sequence: 1 }, limit }
    );
    res.json({
      changes: scanned
        .filter((row) => Object.prototype.hasOwnProperty.call(KINDS, row.kind))
        .map((row) => ({
          sequence: row.sequence,
          kind: row.kind,
          id: row.entity_id,
          revision: row.revision,
          deleted: !!row.deleted,
          payload: row.deleted ? null : (row.payload?.payload ?? null),
          updated_at: row.payload?.updated_at ?? row.created_at,
        })),
      cursor: scanned.at(-1)?.sequence ?? after,
      has_more: scanned.length === limit,
    });
  })
);

module.exports = router;
module.exports.KINDS = KINDS;
