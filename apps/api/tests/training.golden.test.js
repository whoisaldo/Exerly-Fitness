// The JavaScript training maths against the golden file ExerlyCore writes
// (apps/ios/ExerlyCore/Tests/ExerlyCoreTests/GoldenTests.swift). Both suites
// assert docs/api/golden/training-v1.json, so the Swift and JavaScript
// implementations agree on every number an agent or a screen shows.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { ExerciseLibrary } = require('../lib/training/library');
const training = require('../lib/training/history');

const root = path.join(__dirname, '..', '..', '..');
const golden = JSON.parse(
  fs.readFileSync(path.join(root, 'docs/api/golden/training-v1.json'), 'utf8')
);
const expected = golden.expected;
const library = ExerciseLibrary.withCustom(golden.customExercises);
const sessions = golden.sessions;
const history = new training.TrainingHistory(
  sessions.filter((s) => s.endedAt),
  library
);

/** Deep equality where numbers agree to 1e-9 relative and a missing key equals null. */
function same(actual, wanted, where = '$') {
  if (wanted === undefined || wanted === null) {
    assert.ok(actual === undefined || actual === null, `${where}: expected null, got ${actual}`);
    return;
  }
  if (typeof wanted === 'number') {
    assert.equal(typeof actual, 'number', `${where}: expected ${wanted}, got ${actual}`);
    const tolerance = 1e-9 * Math.max(1, Math.abs(wanted));
    assert.ok(
      Math.abs(actual - wanted) <= tolerance,
      `${where}: expected ${wanted}, got ${actual}`
    );
    return;
  }
  if (Array.isArray(wanted)) {
    assert.ok(Array.isArray(actual), `${where}: expected an array`);
    assert.equal(actual.length, wanted.length, `${where}: length`);
    wanted.forEach((item, i) => same(actual[i], item, `${where}[${i}]`));
    return;
  }
  if (typeof wanted === 'object') {
    assert.ok(actual && typeof actual === 'object', `${where}: expected an object`);
    const keys = new Set([...Object.keys(wanted), ...Object.keys(actual)]);
    for (const key of keys) same(actual[key], wanted[key], `${where}.${key}`);
    return;
  }
  assert.equal(actual, wanted, where);
}

const withTotal = (t) => ({ ...t, total: training.total(t) });
const volumes = (muscles) =>
  Object.fromEntries(
    Object.entries(muscles).map(([m, v]) => [m, { sets: v.sets, tonnage: withTotal(v.tonnage) }])
  );

test('the API carries an identical copy of ExerlyCore exercise library', () => {
  const core = path.join(root, 'apps/ios/ExerlyCore/Sources/ExerlyCore/Resources/exercises.json');
  const api = path.join(__dirname, '..', 'lib/training/exercises.json');
  assert.ok(
    fs.readFileSync(core).equals(fs.readFileSync(api)),
    'Copy apps/ios/ExerlyCore/Sources/ExerlyCore/Resources/exercises.json to apps/api/lib/training/'
  );
});

test('per-set e1RM, effective load, set credit and tonnage match Swift', () => {
  assert.ok(expected.sets.length > 400);
  for (const entry of expected.sets) {
    const session = sessions.find((s) => s.id === entry.session);
    const set = session.exercises.flatMap((p) => p.sets).find((s) => s.id === entry.set);
    const exercise = library.exercise(entry.exercise);
    const bodyweight = session.bodyweight ?? null;
    same(
      {
        session: session.id,
        set: set.id,
        exercise: exercise.id,
        oneRepMax: training.setOneRepMax(set, exercise, bodyweight),
        effectiveLoad: training.effectiveLoad(set.efforts[0], exercise, bodyweight),
        credit: training.setCredit(set, exercise),
        tonnage: withTotal(training.tonnage(set, exercise, bodyweight)),
      },
      entry,
      `set ${entry.set}`
    );
  }
});

test('session summaries, including local dates across time zones and DST, match Swift', () => {
  const now = new Date(1_800_000_000_000);
  for (const entry of expected.summaries) {
    const s = training.summary(
      sessions.find((x) => x.id === entry.session),
      library,
      now
    );
    same(
      { ...s, session: entry.session, tonnage: withTotal(s.tonnage), muscles: volumes(s.muscles) },
      entry,
      `summary ${entry.session}`
    );
  }
});

test('exercise statistics and e1RM trends match Swift', () => {
  const ids = [...new Set(history.sessions.flatMap((s) => s.exercises.map((p) => p.exerciseID)))];
  const statistics = {};
  const trends = {};
  for (const id of ids) {
    const stats = history.statistics(id);
    if (stats) statistics[id] = stats;
    const trend = history.oneRepMaxTrend(id);
    if (trend.length) {
      trends[id] = trend.map((p) => ({
        date: p.date,
        session: p.sessionID,
        oneRepMax: p.oneRepMax,
      }));
    }
  }
  same(statistics, expected.statistics, 'statistics');
  same(trends, expected.trends, 'trends');
  for (const entry of expected.statisticsInRange) {
    same(
      { ...entry, statistics: history.statistics(entry.exercise, entry.from, entry.through) },
      entry,
      `${entry.exercise} ${entry.from}..${entry.through}`
    );
  }
});

test('personal records match Swift', () => {
  const records = {};
  for (const session of history.sessions) {
    const found = history.records(session);
    if (found.length === 0) continue;
    records[session.id] = found.map((r) => ({
      kind: r.kind,
      exercise: r.exerciseID,
      session: r.sessionID,
      set: r.setID,
      value: r.value,
      previous: r.previous,
      load: r.load,
    }));
  }
  same(records, expected.records, 'records');
});

test('weekly muscle volume matches Swift for Monday and Sunday weeks', () => {
  for (const [name, weekday] of [
    ['monday', 2],
    ['sunday', 1],
  ]) {
    const weeks = history.weeklyMuscleVolume(weekday);
    const shaped = Object.fromEntries(Object.entries(weeks).map(([w, m]) => [w, volumes(m)]));
    same(shaped, expected.weeklyVolume[name], `weeklyVolume.${name}`);
  }
});

test('metric references verify exactly as ExerlyCore does', () => {
  for (const entry of expected.metrics) {
    same(
      { reference: entry.reference, ...training.verifyMetric(entry.reference, history) },
      entry,
      entry.reference.name
    );
  }
});

test('exercise search ranks exactly as ExerlyCore does', () => {
  for (const entry of expected.search) {
    const results = library.search(entry.query, { muscle: entry.muscle }).map((e) => e.id);
    assert.deepEqual(results, entry.results, `search "${entry.query}" ${entry.muscle ?? ''}`);
  }
});

test('local dates and week starts', () => {
  // 23:30 in New York on 2026-10-31 is 03:30 UTC on 2026-11-01.
  assert.equal(
    training.localDate(new Date('2026-11-01T03:30:00Z'), 'America/New_York'),
    '2026-10-31'
  );
  assert.equal(training.localDate(new Date('2026-11-01T03:30:00Z'), 'Not/AZone'), '2026-11-01');
  assert.equal(training.startOfWeek('2026-10-04', 2), '2026-09-28');
  assert.equal(training.startOfWeek('2026-10-04', 1), '2026-10-04');
  assert.equal(training.parseLocalDate('2026-02-29'), null);
  assert.equal(training.parseLocalDate('2028-02-29'), '2028-02-29');
});
