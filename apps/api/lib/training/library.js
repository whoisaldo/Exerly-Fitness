// The exercise library, ported from ExerlyCore's ExerciseLibrary.swift.
//
// exercises.json is a byte-for-byte copy of ExerlyCore's bundled resource
// (tests/training.golden.test.js keeps them identical), because the API image
// is built from apps/api alone.

const bundled = require('./exercises.json').exercises.map(normalizeExercise);

const ABBREVIATIONS = { db: 'dumbbell', bb: 'barbell', kb: 'kettlebell', bw: 'bodyweight' };

/** Fills the defaults ExerlyCore's decoder applies. */
function normalizeExercise(raw) {
  return {
    id: raw.id,
    name: raw.name,
    aliases: raw.aliases ?? [],
    category: raw.category ?? 'strength',
    metric: raw.metric,
    laterality: raw.laterality ?? 'bilateral',
    mechanics: raw.mechanics,
    region: raw.region,
    muscles: raw.muscles ?? {},
    actions: raw.actions ?? [],
    equipment: raw.equipment ?? [],
    support: raw.support ?? [],
    bodyweightShare: raw.bodyweight ?? 0,
  };
}

/** Lowercased words without diacritics or punctuation, with gym abbreviations expanded. */
function tokens(text) {
  return text
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .toLowerCase()
    .replaceAll("'", '')
    .split(/[^\p{L}\p{N}]+/u)
    .filter(Boolean)
    .map((word) => ABBREVIATIONS[word] ?? word);
}

const normalize = (text) => tokens(text).join(' ');

/** Lower is better; null means no match. */
function score(query, keys) {
  if (query.length === 0) return 0;
  const joined = query.join(' ');
  const compact = query.join('');
  let best = null;
  keys.forEach((key, position) => {
    const penalty = position === 0 ? 0 : 1;
    const compactKey = key.replaceAll(' ', '');
    const words = key.split(' ');
    let value = null;
    if (key === joined || compactKey === compact) value = penalty;
    else if (key.startsWith(joined) || compactKey.startsWith(compact)) value = 2 + penalty;
    else if (query.every((token) => words.some((word) => word.startsWith(token))))
      value = 4 + penalty;
    else if (compactKey.includes(compact)) value = 6 + penalty;
    if (value !== null && (best === null || value < best)) best = value;
  });
  return best;
}

const collator = new Intl.Collator('en', { sensitivity: 'accent' });

class ExerciseLibrary {
  constructor(exercises) {
    this.exercises = exercises;
    this.byID = new Map(exercises.map((exercise) => [exercise.id, exercise]));
    this.keys = exercises.map((exercise) => [exercise.name, ...exercise.aliases].map(normalize));
  }

  /** The bundled library plus an account's custom exercises. A bundled ID wins. */
  static withCustom(customExercises = []) {
    const added = customExercises
      .map(normalizeExercise)
      .filter((exercise) => !bundled.some((b) => b.id === exercise.id));
    return new ExerciseLibrary([...bundled, ...added]);
  }

  exercise(id) {
    return this.byID.get(id) ?? null;
  }

  /**
   * Exercises matching `query`, best first; an empty query lists all,
   * alphabetically. `muscle` keeps exercises that target it.
   */
  search(query, { muscle } = {}) {
    const queryTokens = tokens(query);
    const ranked = [];
    this.exercises.forEach((exercise, index) => {
      if (muscle && exercise.muscles[muscle] !== 1) return;
      const value = score(queryTokens, this.keys[index]);
      if (value !== null) ranked.push({ value, exercise });
    });
    ranked.sort((a, b) =>
      a.value !== b.value ? a.value - b.value : collator.compare(a.exercise.name, b.exercise.name)
    );
    return ranked.map((entry) => entry.exercise);
  }
}

const MUSCLES = [
  'chest',
  'frontDelts',
  'sideDelts',
  'rearDelts',
  'lats',
  'upperTraps',
  'midBack',
  'lowerBack',
  'biceps',
  'triceps',
  'forearms',
  'abs',
  'obliques',
  'glutes',
  'abductors',
  'adductors',
  'hipFlexors',
  'quads',
  'hamstrings',
  'calves',
  'neck',
];

module.exports = { ExerciseLibrary, MUSCLES, tokens };
