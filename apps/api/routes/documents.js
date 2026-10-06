// v1 document sync for ExerlyCore entities. See docs/design/003-document-sync.md
// and, for what personal access tokens may do, docs/design/004-agent-core.md.
//
// Every write runs inside the mutation transaction (lib/mutations.js), so the
// document, its change-feed entry, any audit event and the idempotency
// receipt commit together.

const express = require('express');

const store = require('../data');
const { asyncHandler, badRequest, conflict, forbidden, notFound } = require('../lib/errors');
const { authenticate } = require('../lib/auth');
const { canonicalJSON } = require('../lib/mutations');
const v = require('../lib/validate');
const docs = require('../lib/documents');
const { accountLibrary, agentDocumentProblems, DATA_KINDS } = require('../lib/agentTools');

const router = express.Router();
router.use(authenticate);

function readBase(value) {
  if (value == null || value === '') throw badRequest('base_revision is required; use 0 to create');
  return v.int(value, 'base_revision', { min: 0 });
}

const canWrite = (pat) => pat.scopes.includes('write');
const canPropose = (pat) => canWrite(pat) || pat.scopes.includes('propose');

function checkAgentDocument(kind, id, payload, library, where) {
  const problems = agentDocumentProblems(kind, id, payload, library);
  if (problems.length) {
    throw badRequest(`${where} is not a valid ${kind}: ${problems.slice(0, 5).join('; ')}`);
  }
}

/**
 * What a personal access token may write. Tokens never decide proposals or
 * write audit events: the person decides, and the server keeps the log.
 * Training and nutrition documents, written or proposed, must be ones
 * ExerlyCore can apply; agents can't write the other kinds.
 * Returns the payload to store, with a proposal's author set to the token.
 */
/** Whether a token may write this kind at all, checked before the payload. */
function tokenMayWrite(pat, kind) {
  if (kind === 'audit_event') throw forbidden('Audit events are written by the server');
  if (kind === 'proposal' && !canPropose(pat)) throw forbidden('This token cannot file proposals');
  if (kind !== 'proposal' && !canWrite(pat))
    throw forbidden('This token cannot change data; file a proposal instead');
}

async function tokenWrite(account, pat, kind, base, existing, payload) {
  if (kind === 'proposal') {
    if (existing || base !== 0)
      throw forbidden('Tokens can file new proposals; only you can decide them');
    if (payload.status !== 'pending') throw forbidden('A token can only file pending proposals');
    const library = await accountLibrary(account);
    payload.changes.forEach((change, i) => {
      if (!DATA_KINDS.includes(change.kind))
        throw badRequest(`changes[${i}].kind must be ${DATA_KINDS.join(' or ')}`);
      if (change.after != null) {
        checkAgentDocument(change.kind, change.id, change.after, library, `changes[${i}].after`);
      }
    });
    return { ...payload, author: docs.tokenActor(pat) };
  }
  checkAgentDocument(kind, payload.id, payload, await accountLibrary(account), 'payload');
  return payload;
}

router.get(
  '/documents/:kind/:id',
  asyncHandler(async (req, res) => {
    const row = await docs.current(
      req.account,
      docs.readKind(req.params.kind),
      docs.readID(req.params.id)
    );
    if (!row) throw notFound('Document not found');
    res.json(docs.present(row));
  })
);

router.put(
  '/documents/:kind/:id',
  asyncHandler(async (req, res) => {
    const kind = docs.readKind(req.params.kind);
    const id = docs.readID(req.params.id);
    const base = readBase(req.body?.base_revision);
    if (req.pat) tokenMayWrite(req.pat, kind);
    let payload = docs.readPayload(kind, id, req.body?.payload);
    const existing = await docs.current(req.account, kind, id);
    if (req.pat) payload = await tokenWrite(req.account, req.pat, kind, base, existing, payload);
    if (docs.APPEND_ONLY.has(kind) && existing) {
      if (
        base === existing.revision &&
        canonicalJSON(existing.payload) === canonicalJSON(payload)
      ) {
        return res.json(docs.acknowledge(existing));
      }
      throw badRequest(`${kind} documents cannot be changed`);
    }
    if (base !== (existing?.revision ?? 0)) {
      throw conflict('This document changed on another device. Merge and retry.', {
        document: existing ? docs.present(existing) : null,
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
    await docs.record(req.account, row);
    if (req.pat) {
      const actor = docs.tokenActor(req.pat);
      await docs.appendAudit(
        req.account,
        kind === 'proposal'
          ? {
              action: 'proposalFiled',
              actor,
              proposalID: id,
              targets: payload.changes.map((c) => ({ kind: String(c.kind), id: String(c.id) })),
            }
          : { action: 'directWrite', actor, targets: [{ kind, id }] }
      );
    }
    res.status(existing ? 200 : 201).json(docs.acknowledge(row));
  })
);

router.delete(
  '/documents/:kind/:id',
  asyncHandler(async (req, res) => {
    const kind = docs.readKind(req.params.kind);
    const id = docs.readID(req.params.id);
    const base = readBase(req.query.base_revision ?? req.body?.base_revision);
    if (docs.APPEND_ONLY.has(kind)) throw badRequest(`${kind} documents cannot be deleted`);
    if (req.pat && (!canWrite(req.pat) || kind === 'proposal')) {
      throw forbidden('This token cannot delete documents');
    }
    const existing = await docs.current(req.account, kind, id);
    if (!existing) throw notFound('Document not found');
    if (base !== existing.revision) {
      throw conflict('This document changed on another device. Merge and retry.', {
        document: docs.present(existing),
      });
    }
    if (existing.deleted_at) return res.json(docs.acknowledge(existing));
    const now = new Date();
    const row = await store.update(
      'documents',
      { id: existing.id },
      { revision: base + 1, payload: null, deleted_at: now, updated_at: now }
    );
    await docs.record(req.account, row);
    if (req.pat) {
      await docs.appendAudit(req.account, {
        action: 'directWrite',
        actor: docs.tokenActor(req.pat),
        targets: [{ kind, id }],
        note: 'deleted',
      });
    }
    res.json(docs.acknowledge(row));
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
        .filter((row) => docs.isKind(row.kind))
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
