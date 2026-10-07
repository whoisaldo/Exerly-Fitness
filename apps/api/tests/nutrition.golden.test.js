// The JavaScript energy balance against the golden file ExerlyCore writes
// (NutritionGoldenTests): same days in, same trend weight and expenditure out,
// so an agent reading through MCP sees what the phone shows.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { estimate } = require('../lib/nutrition/energyBalance');
const { NUTRIENTS, NUTRIENT_UNITS, FOOD_SOURCES } = require('../lib/nutrition/validate');

const golden = JSON.parse(
  fs.readFileSync(path.join(__dirname, '../../../docs/api/golden/nutrition-v1.json'), 'utf8')
);
const close = (a, b) => Math.abs(a - b) <= 1e-9 * Math.max(1, Math.abs(b));

test('the port reproduces ExerlyCore on every golden case', () => {
  assert.equal(golden.cases.length, 3);
  for (const c of golden.cases) {
    const days = c.days.map((day) => ({
      date: day.date,
      intake: day.intake ?? null,
      weights: day.weights,
    }));
    const ours = estimate(days, { prior: c.prior ?? null });
    assert.equal(ours.length, c.estimates.length, c.name);
    ours.forEach((mine, i) => {
      const theirs = c.estimates[i];
      assert.equal(mine.date, theirs.date, c.name);
      for (const key of ['trend', 'trendError', 'expenditure', 'expenditureError']) {
        assert.ok(
          close(mine[key], theirs[key]),
          `${c.name} ${mine.date} ${key}: ${mine[key]} vs ${theirs[key]}`
        );
      }
      for (const key of ['weight', 'intake']) {
        const expected = theirs[key] ?? null;
        assert.ok(
          expected === null ? mine[key] === null : close(mine[key], expected),
          `${c.name} ${mine.date} ${key}`
        );
      }
    });
  }
});

test("the validators know exactly ExerlyCore's nutrients and food sources", () => {
  assert.deepEqual(NUTRIENTS, golden.nutrients);
  assert.deepEqual(FOOD_SOURCES, golden.foodSources);
  assert.deepEqual(NUTRIENT_UNITS, golden.nutrientUnits);
});
