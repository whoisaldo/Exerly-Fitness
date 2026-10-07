// The bundled USDA generic foods: every one is a Food ExerlyCore accepts, in
// its units, and search puts the food a person means first.

const test = require('node:test');
const assert = require('node:assert/strict');
const generic = require('../lib/genericFoods');
const { NUTRIENTS, NUTRIENT_UNITS, foodProblems } = require('../lib/nutrition/validate');

const now = new Date('2026-10-07T12:00:00.000Z');
const first = (query) => generic.search(query, 1, { now })[0]?.name;

test('every generic food is a valid Food in ExerlyCore units', () => {
  const { table } = generic;
  assert.equal(table.foods.length, 5431);
  assert.equal(table.license, 'Public domain (CC0 1.0)');
  for (const nutrient of table.nutrients) {
    assert.ok(NUTRIENTS.includes(nutrient), nutrient);
    assert.equal(table.units[nutrient], NUTRIENT_UNITS[nutrient], nutrient);
  }
  for (const [fdcId] of table.foods) {
    const food = generic.byID(`usda:${fdcId}`, { now });
    assert.deepEqual(foodProblems(food, food.id), [], food.name);
    assert.equal(typeof food.per100g.energy, 'number', food.name);
  }
  assert.equal(generic.byID('usda:1'), null);
});

test('a generic food keeps unknown nutrients out and has household portions', () => {
  const banana = generic.search('banana', 1, { now })[0];
  assert.equal(banana.id, 'usda:2709224');
  assert.equal(banana.name, 'Banana, raw');
  assert.equal(banana.source, 'usda');
  assert.equal(banana.per100g.energy, 97);
  assert.equal(banana.per100g.potassium, 326);
  assert.ok(!('leucine' in banana.per100g), 'FNDDS has no amino acids: unknown, not zero');
  assert.ok(!('addedSugars' in banana.per100g));
  assert.deepEqual(
    banana.servings.find((serving) => serving.name === '1 banana'),
    { name: '1 banana', grams: 126 }
  );
  assert.equal(banana.createdAt, now.toISOString());
});

test('search puts the food the query names first', () => {
  assert.equal(first('banana'), 'Banana, raw');
  assert.equal(first('Bananas'), 'Banana, raw');
  assert.equal(first('eggs'), 'Egg, whole, raw');
  assert.equal(first('salmon'), 'Fish, salmon, raw');
  assert.equal(first('ground beef'), 'Beef, ground, raw');
  assert.equal(first('strawberries'), 'Strawberries, raw');
  assert.equal(first('cheddar cheese'), 'Cheese, Cheddar');
  assert.equal(first('peanut butter'), 'Peanut butter');
  assert.equal(first('crème brûlée')?.startsWith('Creme brulee'), true);
  assert.deepEqual(generic.search('zzqx', 5), []);
  assert.deepEqual(generic.search('  ', 5), []);
  assert.equal(generic.search('chicken', 7).length, 7);
});
