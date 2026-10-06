// /v1/foods: search and barcode lookup as ExerlyCore Foods. The provider is
// stubbed; the mapping itself is pinned by foods.golden.test.js.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const { startServer, signUp } = require('./helpers/server');
const providers = require('../lib/foodProviders');

const golden = JSON.parse(
  fs.readFileSync(path.join(__dirname, '../../../docs/api/golden/foods-v1.json'), 'utf8')
);
const original = {
  search: providers.searchOpenFoodFactsProducts,
  barcode: providers.openFoodFactsBarcode,
};
let api;
test.before(async () => {
  api = await startServer();
});
test.after(async () => {
  providers.searchOpenFoodFactsProducts = original.search;
  providers.openFoodFactsBarcode = original.barcode;
  await api.close();
});

test('search returns Foods ExerlyCore can save, with attribution, to sessions and tokens', async () => {
  const user = await signUp(api);
  let asked;
  providers.searchOpenFoodFactsProducts = async (query, limit) => {
    asked = { query, limit };
    return golden.products;
  };
  const res = await api.get('/v1/foods/search?q=oat%20bar&limit=5', { token: user.token });
  assert.equal(res.status, 200, JSON.stringify(res.body));
  assert.deepEqual(asked, { query: 'oat bar', limit: 5 });
  assert.deepEqual(
    res.body.foods.map((food) => food.id),
    ['off:0012345678905', 'off:5000000000017', 'off:76543210']
  );
  assert.match(res.body.attribution, /Open Food Facts.*Open Database License/);

  const created = await api.post(
    '/v1/tokens',
    { name: 'Synthetic agent', scopes: ['read'] },
    { token: user.token, headers: { 'Idempotency-Key': randomUUID() } }
  );
  const byToken = await api.get('/v1/foods/search?q=oat', { token: created.body.token });
  assert.equal(byToken.status, 200);

  assert.equal((await api.get('/v1/foods/search?q=o', { token: user.token })).status, 400);
  assert.equal((await api.get('/v1/foods/search?q=oat')).status, 401);
});

test('a barcode is one Food, or a clear not found, busy or unavailable', async () => {
  const user = await signUp(api);
  const get = (code) => api.get(`/v1/foods/barcode/${code}`, { token: user.token });
  providers.openFoodFactsBarcode = async (identity) => ({
    status: 'found',
    product: { ...golden.products[0], code: identity.openFoodFacts },
  });
  const found = await get('0012345678905');
  assert.equal(found.status, 200, JSON.stringify(found.body));
  assert.equal(found.body.food.id, 'off:0012345678905');
  assert.equal(found.body.food.per100g.sodium, 240);

  providers.openFoodFactsBarcode = async () => ({ status: 'not_found' });
  assert.equal((await get('0012345678905')).status, 404);
  providers.openFoodFactsBarcode = async () => ({ status: 'rate_limited', retry_after: 30 });
  const busy = await get('0012345678905');
  assert.equal(busy.status, 429);
  assert.equal(busy.headers.get('retry-after'), '30');
  providers.openFoodFactsBarcode = async () => ({ status: 'temporarily_unavailable' });
  assert.equal((await get('0012345678905')).status, 503);
  assert.equal((await get('12ab')).status, 400);
});
