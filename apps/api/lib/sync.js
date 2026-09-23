const { randomUUID } = require('node:crypto');
const store = require('../data');
const { badRequest, conflict } = require('./errors');

function entityID(value) {
  if (value == null) return randomUUID();
  if (
    typeof value !== 'string' ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
  ) {
    throw badRequest('client_id must be a UUID');
  }
  return value.toLowerCase();
}
function checkRevision(req, current) {
  const raw = req.get('If-Match') ?? req.body?.base_revision;
  if (raw == null) return; // Compatibility for installed clients during rollout.
  const revision = Number(String(raw).replace(/^"|"$/g, ''));
  if (!Number.isInteger(revision) || revision < 0) throw badRequest('Invalid base revision');
  if (revision !== (current.revision ?? 1)) {
    throw conflict('This entry changed on another device. Review both versions before saving.', {
      current,
    });
  }
}
async function change(user, kind, record) {
  return store.transaction(async () => {
    const cursor = await store.findOne('sync_cursors', { account_id: user.id });
    const sequence = (cursor?.sequence ?? 0) + 1;
    await store.upsert('sync_cursors', { account_id: user.id }, { sequence });
    await store.insert('sync_changes', {
      account_id: user.id,
      sequence,
      kind,
      entity_id: record.client_id || record.id,
      server_id: record.id,
      revision: record.revision ?? 1,
      deleted: !!record.deleted_at,
      payload: record,
      created_at: new Date(),
    });
    return sequence;
  });
}
module.exports = { entityID, checkRevision, change };
