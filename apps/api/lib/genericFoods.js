// Generic foods ("Banana, raw", "Chicken breast, baked, broiled, or roasted")
// from USDA's FNDDS, bundled so searching them needs no key and no provider
// call. Built by scripts/build-generic-foods.js; see
// docs/design/023-generic-foods.md. Results are ExerlyCore Foods, like
// coreFoods.fromOpenFoodFacts gives.

const table = require('./genericFoods.json');

const ATTRIBUTION = 'Generic foods from USDA FoodData Central (FNDDS 2021-2023), public domain.';

const words = (text) =>
  text
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .toLowerCase()
    .replaceAll("'", '')
    .split(/[^\p{L}\p{N}]+/u)
    .filter(Boolean);

/** A query word in the singular, so "eggs" finds "Egg" and "berries" "Berry". */
const singular = (word) =>
  word.length > 3 && word.endsWith('ies')
    ? `${word.slice(0, -3)}y`
    : word.length > 3 && word.endsWith('s') && !word.endsWith('ss')
      ? word.slice(0, -1)
      : word;

const foods = table.foods.map(([fdcId, name, category, values, portions]) => {
  // Each comma-separated part, in the singular: "Fish, salmon, raw" is
  // [["fish"], ["salmon"], ["raw"]]. The first names the food.
  const parts = name.split(',').map((part) => words(part).map(singular));
  return {
    fdcId,
    name,
    category,
    values,
    portions,
    parts,
    words: parts.flat(),
    plain: parts.slice(1).some((part) => ['raw', 'nf'].includes(part.join(' '))),
  };
});

const sameWords = (a, b) => a.length === b.length && [...a].sort().join() === [...b].sort().join();

/**
 * How directly a food is named by the query: 0 when its first part is the
 * query ("Banana" for banana), k when its first k + 1 parts are ("Beef,
 * ground" for ground beef), or a later part alone is ("Fish, salmon").
 */
function naming(food, wanted) {
  for (let k = 0; k < food.parts.length; k++) {
    if (sameWords(food.parts.slice(0, k + 1).flat(), wanted)) return k;
  }
  const part = food.parts.findIndex((p) => sameWords(p, wanted));
  return part >= 0 ? part : Infinity;
}

/** The food as ExerlyCore's Food: nutrients per 100 g, unknowns left out. */
function toFood(food, now) {
  const per100g = {};
  table.nutrients.forEach((nutrient, i) => {
    if (food.values[i] != null) per100g[nutrient] = food.values[i];
  });
  return {
    id: `usda:${food.fdcId}`,
    name: food.name,
    source: 'usda',
    per100g,
    servings: food.portions.map(([name, grams]) => ({ name, grams })),
    favorite: false,
    createdAt: now.toISOString(),
  };
}

/**
 * Generic foods matching every word of `query`, best first: foods the query
 * names (see `naming`), then foods whose first part holds more of it, whole
 * words before prefixes, plain forms ("raw", "NFS") before prepared ones,
 * then the shortest descriptions.
 */
function search(query, limit = 20, { now = new Date() } = {}) {
  const wanted = words(query).map(singular);
  if (!wanted.length) return [];
  const ranked = [];
  for (const food of foods) {
    const matches = (list, word) => list.some((w) => w.startsWith(word));
    if (!wanted.every((word) => matches(food.words, word))) continue;
    ranked.push({
      food,
      rank: [
        Math.min(naming(food, wanted), 9),
        wanted.filter((word) => !matches(food.parts[0], word)).length,
        -wanted.filter((word) => food.words.includes(word)).length,
        food.plain ? 0 : 1,
        food.name.length,
        food.fdcId,
      ],
    });
  }
  ranked.sort((a, b) => {
    for (let i = 0; i < a.rank.length; i++)
      if (a.rank[i] !== b.rank[i]) return a.rank[i] - b.rank[i];
    return 0;
  });
  return ranked.slice(0, limit).map(({ food }) => toFood(food, now));
}

const byFdcID = new Map(foods.map((food) => [food.fdcId, food]));

/** The generic food with this ID ("usda:<fdcId>"), or null. */
function byID(id, { now = new Date() } = {}) {
  const food = byFdcID.get(Number(String(id).replace(/^usda:/, '')));
  return food ? toFood(food, now) : null;
}

module.exports = { ATTRIBUTION, byID, search, table };
