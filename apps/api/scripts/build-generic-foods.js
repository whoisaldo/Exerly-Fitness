#!/usr/bin/env node
// Builds lib/genericFoods.json from USDA FoodData Central's FNDDS download
// (Survey foods, JSON), which is public domain. See
// docs/design/023-generic-foods.md.
//
//   curl -LO https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_survey_food_json_2024-10-31.zip
//   unzip FoodData_Central_survey_food_json_2024-10-31.zip
//   node scripts/build-generic-foods.js surveyDownload.json

const fs = require('node:fs');
const path = require('node:path');

const SOURCE = {
  name: 'USDA FoodData Central, Food and Nutrient Database for Dietary Studies 2021-2023',
  url: 'https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_survey_food_json_2024-10-31.zip',
  published: '2024-10-31',
  license: 'Public domain (CC0 1.0)',
};

// FNDDS nutrient numbers for each ExerlyCore nutrient, in its unit already.
// A list is summed. FNDDS reports fatty acids by chain: 18:3 stands for ALA
// and 18:2 for linoleic acid, as USDA's own intake tables do.
const NUTRIENTS = {
  energy: '208',
  protein: '203',
  carbohydrate: '205',
  fat: '204',
  fiber: '291',
  sugars: '269',
  saturatedFat: '606',
  monounsaturatedFat: '645',
  polyunsaturatedFat: '646',
  omega3: ['619', '629', '631', '621'],
  omega3ALA: '619',
  omega3EPA: '629',
  omega3DHA: '621',
  omega6: ['618', '620'],
  cholesterol: '601',
  sodium: '307',
  potassium: '306',
  calcium: '301',
  iron: '303',
  magnesium: '304',
  phosphorus: '305',
  zinc: '309',
  copper: '312',
  selenium: '317',
  vitaminA: '320',
  vitaminC: '401',
  vitaminD: '328',
  vitaminE: '323',
  vitaminK: '430',
  thiamin: '404',
  riboflavin: '405',
  niacin: '406',
  vitaminB6: '415',
  vitaminB12: '418',
  folate: '435',
  choline: '421',
  alcohol: '221',
  caffeine: '262',
  water: '255',
};

const round = (value) => Math.round(value * 1000) / 1000;

/** Each nutrient's unit in FNDDS, written as ExerlyCore writes it. */
function unitsOf(foods) {
  const units = new Map();
  for (const food of foods)
    for (const { nutrient } of food.foodNutrients)
      units.set(nutrient.number, nutrient.unitName.replace('µg', 'mcg'));
  return Object.fromEntries(
    Object.entries(NUTRIENTS).map(([name, numbers]) => {
      const found = new Set([numbers].flat().map((number) => units.get(number)));
      if (found.size !== 1) throw new Error(`${name} mixes units: ${[...found]}`);
      return [name, [...found][0]];
    })
  );
}

function build(foods) {
  const order = Object.keys(NUTRIENTS);
  const units = unitsOf(foods);
  const rows = [];
  for (const food of foods) {
    const amounts = new Map(food.foodNutrients.map((n) => [n.nutrient.number, n.amount]));
    if (!amounts.has('208')) continue;
    const values = order.map((name) => {
      const numbers = [NUTRIENTS[name]].flat();
      if (!numbers.every((number) => typeof amounts.get(number) === 'number')) return null;
      return round(numbers.reduce((sum, number) => sum + amounts.get(number), 0));
    });
    const portions = [];
    for (const portion of [...food.foodPortions].sort(
      (a, b) => a.sequenceNumber - b.sequenceNumber
    )) {
      const name = portion.portionDescription?.trim();
      if (!(portion.gramWeight > 0) || !name || name === 'Quantity not specified') continue;
      if (portions.some(([existing]) => existing === name) || portions.length === 6) continue;
      portions.push([name, round(portion.gramWeight)]);
    }
    rows.push([
      food.fdcId,
      food.description.trim(),
      food.wweiaFoodCategory?.wweiaFoodCategoryDescription ?? '',
      values,
      portions,
    ]);
  }
  rows.sort((a, b) => a[0] - b[0]);
  return { ...SOURCE, nutrients: order, units, foods: rows };
}

if (require.main === module) {
  const input = process.argv[2];
  if (!input) {
    console.error('Usage: node scripts/build-generic-foods.js surveyDownload.json');
    process.exit(1);
  }
  const { SurveyFoods } = JSON.parse(fs.readFileSync(input, 'utf8'));
  const table = build(SurveyFoods);
  const out = path.join(__dirname, '..', 'lib', 'genericFoods.json');
  // One food a line, so a new release reads as a diff.
  const lines = table.foods.map((row) => JSON.stringify(row));
  const { foods, ...header } = table;
  fs.writeFileSync(
    out,
    `${JSON.stringify(header).slice(0, -1)},"foods":[\n${lines.join(',\n')}\n]}\n`
  );
  console.log(`${foods.length} foods written to ${path.relative(process.cwd(), out)}`);
}

module.exports = { NUTRIENTS, build };
