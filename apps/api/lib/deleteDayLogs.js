const store = require('../data');
const sync = require('./sync');

// Both user and administrator resets must reach devices with cached entries.
module.exports = async function deleteDayLogs(user, day) {
  return store.transaction(async () => {
    const filter = { email: user.email, entry_date: day };
    const removed = Object.fromEntries(
      await Promise.all(
        ['activities', 'food', 'sleep'].map(async (collection) => [
          collection,
          await store.find(collection, filter),
        ])
      )
    );
    for (const [collection, kind] of [
      ['activities', 'activity'],
      ['food', 'food'],
      ['sleep', 'sleep'],
    ]) {
      for (const entry of removed[collection]) {
        const clientID =
          entry.client_id ?? (kind === 'food' ? sync.entityID() : `legacy-${entry.id}`);
        const deleted = await store.update(
          collection,
          { id: entry.id, email: user.email },
          {
            account_id: user.id,
            client_id: clientID,
            ...(kind === 'food'
              ? {}
              : { identity_key: `${user.id}:${clientID}`, revision_locked: true }),
            revision: (entry.revision ?? 1) + 1,
            deleted_at: new Date(),
            updated_at: new Date(),
          }
        );
        await sync.change(user, kind, deleted);
      }
    }
    return removed;
  });
};
