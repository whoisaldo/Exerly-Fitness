const test = require('node:test');
const assert = require('node:assert/strict');
const { startServer, signUp } = require('./helpers/server');
const providers = require('../lib/foodProviders');
let api;
const originalLookup = providers.lookupBarcode;
test.before(async () => {
  api = await startServer();
});
test.after(async () => {
  providers.lookupBarcode = originalLookup;
  await api.close();
});

test('personal barcode overrides win without calling a provider and stay account-scoped', async () => {
  const user = await signUp(api);
  const other = await signUp(api);
  await api.post(
    '/api/library/foods',
    { name: 'My cereal', barcode: '036000291452', calories: 110, protein: 3 },
    { token: user.token }
  );
  let calls = 0;
  providers.lookupBarcode = async () => {
    calls++;
    return { status: 'not_found' };
  };
  const mine = await api.post(
    '/api/food/barcode-lookup',
    { barcode: '0036000291452', symbology: 'ean13' },
    { token: user.token }
  );
  assert.equal(mine.body.food.name, 'My cereal');
  assert.equal(calls, 0);
  const theirs = await api.get('/api/food/barcode/036000291452?symbology=upca', {
    token: other.token,
  });
  assert.equal(theirs.body.status, 'not_found');
  assert.equal(calls, 1);
});

test('an outage is not cached as a miss; a later successful lookup can recover', async () => {
  const user = await signUp(api);
  providers.lookupBarcode = async () => ({ status: 'temporarily_unavailable' });
  const path = '/api/food/barcode/036000291452?symbology=upca';
  assert.equal((await api.get(path, { token: user.token })).body.status, 'temporarily_unavailable');
  assert.equal(await api.store.count('barcode_cache'), 0);
  providers.lookupBarcode = async () => ({
    status: 'found',
    food: providers.mapOpenFoodFactsProduct({
      product_name: 'Recovered cereal',
      nutriments: { 'energy-kcal_100g': 200 },
    }),
  });
  assert.equal((await api.get(path, { token: user.token })).body.status, 'found');
  assert.equal(await api.store.count('barcode_cache'), 1);
  providers.lookupBarcode = async () => {
    throw new Error('Should use cache');
  };
  assert.equal((await api.get(path, { token: user.token })).body.food.cached, true);
});
