// The shapes ExerlyCore decodes for nutrition documents an agent writes or
// proposes (Nutrition.swift): what decoding requires, plus FoodEntry.problems
// and Food.problems. The nutrient and source lists are ExerlyCore's own;
// tests/nutrition.golden.test.js checks them against docs/api/golden/nutrition-v1.json.

const NUTRIENTS = [
  'energy',
  'protein',
  'carbohydrate',
  'fat',
  'fiber',
  'sugars',
  'addedSugars',
  'starch',
  'saturatedFat',
  'monounsaturatedFat',
  'polyunsaturatedFat',
  'transFat',
  'omega3',
  'omega3ALA',
  'omega3EPA',
  'omega3DHA',
  'omega6',
  'cholesterol',
  'sodium',
  'potassium',
  'calcium',
  'iron',
  'magnesium',
  'phosphorus',
  'zinc',
  'copper',
  'manganese',
  'selenium',
  'vitaminA',
  'vitaminC',
  'vitaminD',
  'vitaminE',
  'vitaminK',
  'thiamin',
  'riboflavin',
  'niacin',
  'pantothenicAcid',
  'vitaminB6',
  'vitaminB12',
  'folate',
  'choline',
  'alcohol',
  'caffeine',
  'water',
  'histidine',
  'isoleucine',
  'leucine',
  'lysine',
  'methionine',
  'phenylalanine',
  'threonine',
  'tryptophan',
  'valine',
  'cystine',
  'tyrosine',
];
const FOOD_SOURCES = ['custom', 'recipe', 'usda', 'openFoodFacts', 'fatSecret', 'imported'];

const UUID_RE = /^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$/;
const INSTANT_RE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,9})?(Z|[+-]\d{2}:\d{2})$/;
const DATE_RE = /^(\d{4})-(\d{2})-(\d{2})$/;

const isString = (v) => typeof v === 'string';
const isObject = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
const isNumber = (v) => typeof v === 'number' && Number.isFinite(v);
const isInstant = (v) => isString(v) && INSTANT_RE.test(v) && !Number.isNaN(Date.parse(v));
const isDate = (v) => {
  const match = isString(v) && DATE_RE.exec(v);
  if (!match) return false;
  const [year, month, day] = match.slice(1).map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCMonth() === month - 1 && date.getUTCDate() === day;
};
const absent = (v) => v === undefined || v === null;

function amountsProblems(per100g, where) {
  if (!isObject(per100g)) return [`${where} must be an object of nutrient amounts`];
  return Object.entries(per100g).flatMap(([name, amount]) => {
    if (!NUTRIENTS.includes(name)) return [`${where}.${name} is not a nutrient Exerly knows`];
    return isNumber(amount) && amount >= 0
      ? []
      : [`${where}.${name} must be a number of 0 or more`];
  });
}

function snapshotProblems(food, where) {
  if (!isObject(food)) return [`${where} must be an object`];
  const problems = [];
  if (!isString(food.foodID) || food.foodID === '') problems.push(`${where}.foodID is required`);
  if (!isString(food.name) || food.name.trim() === '') problems.push(`${where}.name is required`);
  if (!absent(food.brand) && !isString(food.brand)) problems.push(`${where}.brand must be text`);
  if (!FOOD_SOURCES.includes(food.source))
    problems.push(`${where}.source must be one of ${FOOD_SOURCES.join(', ')}`);
  return [...problems, ...amountsProblems(food.per100g, `${where}.per100g`)];
}

function servingProblems(serving, where) {
  if (!isObject(serving)) return [`${where} must be an object`];
  return isString(serving.name) &&
    serving.name.trim() !== '' &&
    isNumber(serving.grams) &&
    serving.grams > 0
    ? []
    : [`${where} needs a name and a positive weight in grams`];
}

/** Problems with a food_entry payload whose document ID is `id`. */
function foodEntryProblems(entry, id) {
  if (!isObject(entry)) return ['payload must be an object'];
  const problems = [];
  if (entry.id !== id || !UUID_RE.test(id ?? ''))
    problems.push('id must be the document ID, a UUID');
  if (!isDate(entry.date)) problems.push('date must be a date written YYYY-MM-DD');
  if (!isString(entry.meal) || entry.meal.trim() === '' || entry.meal.length > 40)
    problems.push('meal needs a name up to 40 characters');
  if (!isInstant(entry.loggedAt)) problems.push('loggedAt must be an ISO 8601 instant');
  if (!(isNumber(entry.grams) && entry.grams > 0 && entry.grams <= 100000))
    problems.push('grams must be a positive weight up to 100000');
  if (!absent(entry.serving)) problems.push(...servingProblems(entry.serving, 'serving'));
  if (!absent(entry.quantity) && !(isNumber(entry.quantity) && entry.quantity > 0))
    problems.push('quantity must be positive');
  return [...problems, ...snapshotProblems(entry.food, 'food')];
}

/** Problems with a saved_food payload whose document ID is `id`. */
function foodProblems(food, id) {
  if (!isObject(food)) return ['payload must be an object'];
  const problems = [];
  if (food.id !== id || !isString(id) || id === '') problems.push('id must be the document ID');
  if (!isString(food.name) || food.name.trim() === '') problems.push('name is required');
  if (!absent(food.brand) && !isString(food.brand)) problems.push('brand must be text');
  if (!FOOD_SOURCES.includes(food.source))
    problems.push(`source must be one of ${FOOD_SOURCES.join(', ')}`);
  problems.push(...amountsProblems(food.per100g, 'per100g'));
  if (!Array.isArray(food.servings)) problems.push('servings must be an array');
  else food.servings.forEach((s, i) => problems.push(...servingProblems(s, `servings[${i}]`)));
  if (!absent(food.barcode) && !isString(food.barcode)) problems.push('barcode must be text');
  if (typeof food.favorite !== 'boolean') problems.push('favorite must be true or false');
  if (!isInstant(food.createdAt)) problems.push('createdAt must be an ISO 8601 instant');
  if (!absent(food.archivedAt) && !isInstant(food.archivedAt))
    problems.push('archivedAt must be an ISO 8601 instant');
  if (!absent(food.yieldGrams) && !(isNumber(food.yieldGrams) && food.yieldGrams > 0))
    problems.push('the yield must be positive');
  if (
    !absent(food.volume) &&
    !(
      isObject(food.volume) &&
      isNumber(food.volume.density) &&
      food.volume.density > 0.3 &&
      food.volume.density < 3 &&
      typeof food.volume.assumed === 'boolean' &&
      (absent(food.volume.note) || isString(food.volume.note))
    )
  )
    problems.push(
      'the volume basis needs a density between 0.3 and 3 g/ml and whether it is assumed'
    );
  if (!absent(food.ingredients)) {
    if (!Array.isArray(food.ingredients)) problems.push('ingredients must be an array');
    else
      food.ingredients.forEach((ingredient, i) => {
        if (!isObject(ingredient) || !(isNumber(ingredient.grams) && ingredient.grams > 0))
          problems.push(`ingredients[${i}] needs a positive weight`);
        else problems.push(...snapshotProblems(ingredient.food, `ingredients[${i}].food`));
      });
  }
  if (food.source === 'recipe' && !(Array.isArray(food.ingredients) && food.ingredients.length))
    problems.push('a recipe needs ingredients');
  return problems;
}

module.exports = { NUTRIENTS, FOOD_SOURCES, foodEntryProblems, foodProblems };
