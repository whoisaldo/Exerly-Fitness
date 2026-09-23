const test = require('node:test');
const assert = require('node:assert/strict');
const { normalizeBarcode, checkDigit, expandUPCE } = require('../lib/barcodes');
const providers = require('../lib/foodProviders');

test('UPC-A and Apple leading-zero EAN-13 share a GTIN identity', () => {
  assert.equal(
    normalizeBarcode('036000291452', 'upca').identity,
    normalizeBarcode('0036000291452', 'ean13').identity
  );
  assert.equal(normalizeBarcode('036000291452', 'upca').gtin13, '0036000291452');
});

test('UPC-E expands each compression rule before validating its check digit', () => {
  assert.equal(expandUPCE('04210005'), '042000001005');
  for (const last of '0123456789') {
    const partial = `012345${last}0`;
    const expanded = expandUPCE(partial);
    const upce = partial.slice(0, -1) + checkDigit(expanded.slice(0, -1));
    const identity = normalizeBarcode(upce, 'upce');
    assert.equal(identity.status, 'valid');
    assert.equal(identity.identity, normalizeBarcode(expandUPCE(upce), 'upca').identity);
  }
  assert.equal(normalizeBarcode('04210005').status, 'unsupported_format');
  assert.equal(normalizeBarcode('04210005', 'ean8').status, 'invalid_code');
});

test('100 synthetic GTIN fixtures retain leading zeros and detect damaged digits', () => {
  for (let i = 0; i < 100; i++) {
    const body = String(100000 + i).padStart(11, '0');
    const code = body + checkDigit(body);
    assert.equal(normalizeBarcode(code, 'upca').identity, code.padStart(14, '0'));
    const damaged = code.slice(0, -1) + String((Number(code.at(-1)) + 1) % 10);
    assert.equal(normalizeBarcode(damaged, 'upca').status, 'invalid_code');
  }
});

test('GTIN-14 packaging and arbitrary Code 128 do not become retail UPCs', () => {
  const body = '1036000291452';
  const packaging = normalizeBarcode(body + checkDigit(body), 'gtin14');
  assert.equal(packaging.gtin13, null);
  assert.equal(packaging.openFoodFacts.length, 14);
  assert.equal(normalizeBarcode('036000291452', 'code128').status, 'unsupported_format');
  assert.equal(normalizeBarcode(36000291452, 'upca').status, 'invalid_code');
});

test('OFF nutrition keeps volume basis, unknown nutrients and sodium units', () => {
  const food = providers.mapOpenFoodFactsProduct({
    product_name: 'Milk',
    product_quantity_unit: 'ml',
    serving_quantity: 250,
    serving_quantity_unit: 'ml',
    serving_size: '1 cup',
    nutriments: { 'energy-kcal_100g': 52, proteins_100g: 3.4, sodium_100g: 0.04, sugars_100g: 0 },
  });
  assert.equal(food.serving_size, '100 ml');
  assert.equal(food.nutrition_basis.unit, 'ml');
  assert.equal(food.portions[1].multiplier, 2.5);
  assert.equal(food.sodium, 40);
  assert.equal(food.sugar, 0);
  assert.equal(food.fiber, null);
  assert.ok(food.missing_nutrients.includes('fiber'));
  assert.ok(!food.missing_nutrients.includes('sugar'));
});

test('barcode provider misses, outages, throttling and malformed responses stay distinct', async () => {
  const identity = normalizeBarcode('036000291452', 'upca');
  const options = { reserve: async () => true, backoff: async () => {} };
  for (const [status, body, expected] of [
    [404, {}, 'not_found'],
    [200, { result: { id: 'product_not_found' } }, 'not_found'],
    [503, {}, 'temporarily_unavailable'],
    [429, {}, 'rate_limited'],
    [200, {}, 'temporarily_unavailable'],
  ]) {
    const result = await providers.lookupBarcode(identity, {
      ...options,
      fetchImpl: async () => new Response(JSON.stringify(body), { status }),
    });
    assert.equal(result.status, expected);
  }
  const result = await providers.lookupBarcode(identity, {
    ...options,
    fetchImpl: async () => {
      throw new Error('offline');
    },
  });
  assert.equal(result.status, 'temporarily_unavailable');
});

test('OFF requests identify the app and use the documented product API', async () => {
  const identity = normalizeBarcode('036000291452', 'upca');
  let request;
  const result = await providers.lookupBarcode(identity, {
    reserve: async () => true,
    fetchImpl: async (url, options) => {
      request = { url: String(url), options };
      return new Response(JSON.stringify({ product: { product_name: 'Fixture', nutriments: {} } }));
    },
  });
  assert.equal(result.status, 'found');
  assert.match(request.url, /api\/v3\.6\/product\//);
  assert.match(request.options.headers['User-Agent'], /Exerly/);
});

test('an explicit volume serving label stays volume without a density assumption', () => {
  const food = providers.mapOpenFoodFactsProduct({
    product_name: 'Drink',
    serving_size: '100 ml',
    nutriments: { 'energy-kcal_100g': 60 },
  });
  assert.equal(food.nutrition_basis.unit, 'ml');
  assert.equal(food.serving_size, '100 ml');
});
