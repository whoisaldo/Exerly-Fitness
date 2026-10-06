// Open Food Facts products mapped to ExerlyCore Foods, against
// docs/api/golden/foods-v1.json. ExerlyCore's FoodsGoldenTests decode the same
// Foods, so the server can't send a Food the phone can't read. Regenerate with
// EXERLY_WRITE_FOODS_GOLDEN=1 after a deliberate change. The products are synthetic.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { OFF_NUTRIENTS, fromOpenFoodFacts } = require('../lib/coreFoods');

const file = path.join(__dirname, '../../../docs/api/golden/foods-v1.json');
const now = new Date('2026-10-06T12:00:00.000Z');

const products = [
  {
    code: '0012345678905',
    product_name: 'Synthetic oat bar',
    brands: 'Example Mills, Other Brand',
    serving_size: '1 bar (40 g)',
    serving_quantity: 40,
    serving_quantity_unit: 'g',
    nutriments: {
      'energy-kcal_100g': 412,
      proteins_100g: 9.5,
      carbohydrates_100g: 62,
      fat_100g: 13.2,
      fiber_100g: 7.1,
      sugars_100g: 21,
      'added-sugars_100g': 18,
      'saturated-fat_100g': 2.4,
      'trans-fat_100g': 0,
      sodium_100g: 0.24,
      potassium_100g: 0.38,
      calcium_100g: 0.12,
      iron_100g: 0.0036,
      'vitamin-a_100g': 0.00015,
      'vitamin-c_100g': 0.012,
      'vitamin-d_100g': 0.0000025,
      'vitamin-b12_100g': 0.0000012,
      'vitamin-b9_100g': 0.0001,
      'vitamin-pp_100g': 0.0042,
      cholesterol_100g: 0,
      caffeine_100g: 0,
      'omega-3-fat_100g': 0.4,
      alcohol_100g: 0,
    },
  },
  {
    code: '5000000000017',
    product_name_en: 'Synthetic sparkling drink',
    nutrition_data_per: '100ml',
    serving_quantity: 330,
    serving_quantity_unit: 'ml',
    nutriments: {
      energy_100g: 180,
      carbohydrates_100g: 10.6,
      sugars_100g: 10.6,
      sodium_100g: 0.01,
    },
  },
  { code: '4000000000016', nutriments: { 'energy-kcal_100g': 100 } },
  { code: 'not-a-code', product_name: 'No barcode', nutriments: {} },
  {
    code: '76543210',
    product_name: 'Synthetic spread',
    nutriments: { 'energy-kcal_100g': -5, fat_100g: 'lots', proteins_100g: 25.25 },
  },
];

test('Open Food Facts products map to the Foods in the golden file', () => {
  const foods = products.map((product) => fromOpenFoodFacts(product, { now }));
  // Every nutrient the mapper can write, with the factor from grams; ExerlyCore
  // checks each is one of its nutrients and the factor matches its unit.
  const nutrients = Object.values(OFF_NUTRIENTS);
  if (process.env.EXERLY_WRITE_FOODS_GOLDEN === '1') {
    fs.writeFileSync(
      file,
      `${JSON.stringify({ version: 1, nutrients, products, foods }, null, 2)}\n`
    );
  }
  const golden = JSON.parse(fs.readFileSync(file, 'utf8'));
  assert.deepEqual(golden.products, products, 'The fixture products match the golden file');
  assert.deepEqual(golden.nutrients, nutrients);
  assert.deepEqual(foods, golden.foods);
});

test('nutrients land in ExerlyCore units and bad values are left out', () => {
  const [bar, drink, unnamed, uncoded, spread] = products.map((product) =>
    fromOpenFoodFacts(product, { now })
  );
  assert.equal(bar.id, 'off:0012345678905');
  assert.equal(bar.brand, 'Example Mills');
  assert.equal(bar.per100g.sodium, 240, 'mg');
  assert.equal(bar.per100g.iron, 3.6, 'mg');
  assert.equal(bar.per100g.vitaminA, 150, 'µg');
  assert.equal(bar.per100g.vitaminD, 2.5, 'µg');
  assert.equal(bar.per100g.folate, 100, 'µg');
  assert.equal(bar.per100g.niacin, 4.2, 'mg');
  assert.ok(!('alcohol' in bar.per100g), 'alcohol is % by volume in Open Food Facts');
  assert.deepEqual(bar.servings, [{ name: '1 bar (40 g)', grams: 40 }]);
  assert.equal(drink.per100g.energy, 43.021, 'kJ converted to kcal');
  assert.deepEqual(drink.servings, [{ name: '330 ml', grams: 330 }]);
  assert.equal(unnamed, null);
  assert.equal(uncoded, null);
  assert.deepEqual(spread.per100g, { protein: 25.25 });
});
