const store = require('../data');

async function reserve(provider, limit) {
  const now = Date.now();
  const minute = Math.floor(now / 60000);
  return store.transaction(async () => {
    const blocked = await store.findOne('provider_budgets', { key: `${provider}:backoff` });
    if (blocked?.blocked_until > new Date(now)) return false;
    const counter = await store.increment(
      'provider_budgets',
      { key: `${provider}:${minute}` },
      'count',
      1
    );
    await store.update('provider_budgets', { id: counter.id }, { created_at: new Date(now) });
    // Budget records contain no user data and only need a short history.
    await store.remove('provider_budgets', { created_at: { lt: new Date(now - 86400000) } });
    return counter.count <= limit;
  });
}

async function backoff(provider, seconds) {
  await store.upsert(
    'provider_budgets',
    { key: `${provider}:backoff` },
    {
      blocked_until: new Date(Date.now() + Math.max(60, Math.min(seconds || 60, 3600)) * 1000),
      created_at: new Date(),
    }
  );
}

module.exports = { reserve, backoff };
