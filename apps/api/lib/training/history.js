// Training maths, ported line for line from ExerlyCore (OneRepMax.swift,
// Volume.swift, TrainingHistory.swift, Agent.swift's metric references).
// docs/api/golden/training-v1.json, generated from Swift, is asserted by
// tests/training.golden.test.js, so the two implementations can't drift.
//
// Sessions are workout_session document payloads in ExerlyCore's wire format.
// Loads are kilograms, volume kilogram-reps, duration seconds, distance metres.

const { MUSCLES } = require('./library');

const KILOGRAMS_PER_UNIT = { kg: 1, lb: 0.45359237 };
const REP_METRICS = new Set(['weightReps', 'bodyweightReps', 'assistedReps']);
const LOAD_METRICS = new Set([...REP_METRICS, 'weightDuration', 'weightDistance']);
const DURATION_METRICS = new Set(['duration', 'weightDuration', 'distanceDuration']);
const DISTANCE_METRICS = new Set(['distanceDuration', 'weightDistance']);

const kilograms = (mass) => (mass ? mass.value * KILOGRAMS_PER_UNIT[mass.unit] : null);

// ---- Sets ----

const isCompleted = (set) => set.completedAt != null;
const counts = (set) => isCompleted(set) && set.kind !== 'warmUp';
const primary = (set) => set.efforts[0] ?? {};
const sum = (set, field) => set.efforts.reduce((total, effort) => total + (effort[field] ?? 0), 0);

/** RIR of the primary effort: failure sets are 0, drop and myo tops near it. */
function effectiveRIR(set) {
  if (set.kind === 'failure') return 0;
  if (set.kind === 'drop' || set.kind === 'myo') return set.rir ?? 0;
  return set.rir ?? null;
}

// ---- e1RM ----

const MAXIMUM_REPS_TO_FAILURE = 20;

/** Brzycki up to ten reps to failure, Epley above; null past 20. */
function estimateOneRepMax(load, repsToFailure) {
  if (!Number.isFinite(load) || load <= 0 || repsToFailure < 1) return null;
  if (repsToFailure > MAXIMUM_REPS_TO_FAILURE) return null;
  return repsToFailure <= 10 ? (load * 36) / (37 - repsToFailure) : load * (1 + repsToFailure / 30);
}

function oneRepMaxFromReps(load, reps, rir) {
  if (!(reps > 0)) return null;
  return estimateOneRepMax(load, reps + Math.max(0, rir ?? 0));
}

const loadForReps = (reps, oneRepMax) =>
  reps <= 10 ? (oneRepMax * (37 - reps)) / 36 : oneRepMax / (1 + reps / 30);

// ---- Volume ----

/** Resistance and bodyweight components in kilograms; null is unknown. */
function loadParts(effort, exercise, bodyweight) {
  const added = kilograms(effort.load);
  const body = bodyweight ? kilograms(bodyweight) * exercise.bodyweightShare : null;
  switch (exercise.metric) {
    case 'weightReps':
    case 'weightDuration':
    case 'weightDistance':
      return { resistance: added, bodyweight: 0 };
    case 'bodyweightReps':
      return { resistance: added ?? 0, bodyweight: exercise.bodyweightShare === 0 ? 0 : body };
    case 'assistedReps':
      return { resistance: 0, bodyweight: body === null ? null : Math.max(0, body - (added ?? 0)) };
    default:
      return { resistance: null, bodyweight: null };
  }
}

function effectiveLoad(effort, exercise, bodyweight) {
  const parts = loadParts(effort, exercise, bodyweight);
  if (parts.resistance === null || parts.bodyweight === null) return null;
  return parts.resistance + parts.bodyweight;
}

const zeroTonnage = () => ({ resistance: 0, bodyweight: 0, isComplete: true });
const total = (tonnage) => tonnage.resistance + tonnage.bodyweight;

function addTonnage(into, other, factor = 1) {
  into.resistance += other.resistance * factor;
  into.bodyweight += other.bodyweight * factor;
  into.isComplete = into.isComplete && other.isComplete;
}

/** Tonnage of a set, counting every effort. Only rep metrics have tonnage. */
function tonnage(set, exercise, bodyweight) {
  const result = zeroTonnage();
  if (!REP_METRICS.has(exercise.metric)) return result;
  for (const effort of set.efforts) {
    const reps = effort.reps ?? 0;
    if (!(reps > 0)) continue;
    const parts = loadParts(effort, exercise, bodyweight);
    result.resistance += (parts.resistance ?? 0) * reps;
    if (parts.bodyweight === null) result.isComplete = false;
    else result.bodyweight += parts.bodyweight * reps;
  }
  return result;
}

/** 0 for warm-ups, incomplete sets and cardio; 0.5 for one side of a unilateral exercise. */
function setCredit(set, exercise) {
  if (!counts(set) || exercise.category !== 'strength') return 0;
  return exercise.laterality === 'unilateral' && set.side != null ? 0.5 : 1;
}

function accumulate(session, library, into) {
  const bodyweight = session.bodyweight ?? null;
  for (const performed of session.exercises) {
    const exercise = library.exercise(performed.exerciseID);
    if (!exercise) continue;
    for (const set of performed.sets) {
      const credit = setCredit(set, exercise);
      if (credit <= 0) continue;
      const setTonnage = tonnage(set, exercise, bodyweight);
      for (const [muscle, share] of Object.entries(exercise.muscles)) {
        const volume = (into[muscle] ??= { sets: 0, tonnage: zeroTonnage() });
        volume.sets += credit * share;
        addTonnage(volume.tonnage, setTonnage, share);
      }
    }
  }
  return into;
}

const volumeByMuscle = (sessions, library) =>
  sessions.reduce((into, session) => accumulate(session, library, into), {});

// ---- Dates ----

const DATE_RE = /^(\d{4})-(\d{2})-(\d{2})$/;

/** A valid YYYY-MM-DD string, or null. */
function parseLocalDate(text) {
  const match = typeof text === 'string' && DATE_RE.exec(text);
  if (!match) return null;
  const [year, month, day] = match.slice(1).map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (year < 1 || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) return null;
  return text;
}

const formatters = new Map();

/** The calendar date of `instant` in an IANA zone; unknown zones count as UTC. */
function localDate(instant, timeZone) {
  let formatter = formatters.get(timeZone);
  if (!formatter) {
    try {
      formatter = new Intl.DateTimeFormat('en-CA', {
        timeZone,
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        calendar: 'gregory',
        numberingSystem: 'latn',
      });
    } catch {
      return localDate(instant, 'UTC');
    }
    formatters.set(timeZone, formatter);
  }
  const parts = Object.fromEntries(formatter.formatToParts(instant).map((p) => [p.type, p.value]));
  return `${parts.year}-${parts.month}-${parts.day}`;
}

const sessionDate = (session) => localDate(new Date(session.startedAt), session.timeZoneID);

/** The first day of the week holding `date`; weekdays are 1 (Sunday) to 7. */
function startOfWeek(date, firstWeekday) {
  const [year, month, day] = date.split('-').map(Number);
  const utc = Date.UTC(year, month - 1, day);
  const weekday = new Date(utc).getUTCDay() + 1;
  const offset = (weekday - firstWeekday + 7) % 7;
  return new Date(utc - offset * 86_400_000).toISOString().slice(0, 10);
}

// ---- Statistics ----

/** e1RM in kilograms from a set's primary effort. */
function setOneRepMax(set, exercise, bodyweight) {
  const effort = primary(set);
  if (!REP_METRICS.has(exercise.metric) || effort.reps == null) return null;
  const load = effectiveLoad(effort, exercise, bodyweight);
  if (load === null) return null;
  return oneRepMaxFromReps(load, effort.reps, effectiveRIR(set));
}

/** Every metric in MacroFactor's exercise export, from completed working sets. */
function statistics(exercise, records) {
  const result = {
    estimatedOneRepMax: null,
    estimatedThreeRepMax: null,
    estimatedTenRepMax: null,
    totalVolume: 0,
    isVolumeComplete: true,
    bestSetVolume: 0,
    heaviestLoad: null,
    totalReps: 0,
    bestSetReps: 0,
    totalDuration: 0,
    bestSetDuration: 0,
    totalDistance: 0,
    bestSetDistance: 0,
    totalSets: 0,
  };
  let best = null;
  for (const { set, bodyweight } of records) {
    result.totalSets += 1;
    const reps = sum(set, 'reps');
    const duration = sum(set, 'duration');
    const distance = sum(set, 'distance');
    result.totalReps += reps;
    result.bestSetReps = Math.max(result.bestSetReps, reps);
    result.totalDuration += duration;
    result.bestSetDuration = Math.max(result.bestSetDuration, duration);
    result.totalDistance += distance;
    result.bestSetDistance = Math.max(result.bestSetDistance, distance);
    const setTonnage = tonnage(set, exercise, bodyweight);
    const volume = total(setTonnage);
    result.isVolumeComplete = result.isVolumeComplete && setTonnage.isComplete;
    result.totalVolume += volume;
    result.bestSetVolume = Math.max(result.bestSetVolume, volume);
    const load = effectiveLoad(primary(set), exercise, bodyweight);
    if (load !== null && LOAD_METRICS.has(exercise.metric)) {
      result.heaviestLoad = Math.max(result.heaviestLoad ?? load, load);
    }
    const e1rm = setOneRepMax(set, exercise, bodyweight);
    if (e1rm !== null) best = Math.max(best ?? e1rm, e1rm);
  }
  if (best !== null) {
    result.estimatedOneRepMax = best;
    result.estimatedThreeRepMax = loadForReps(3, best);
    result.estimatedTenRepMax = loadForReps(10, best);
  }
  return result;
}

/** Totals for one session; `now` ends an unfinished one. */
function summary(session, library, now) {
  const sets = session.exercises.flatMap((performed) => performed.sets);
  const end = session.endedAt ? Date.parse(session.endedAt) : now.getTime();
  const sessionTonnage = zeroTonnage();
  for (const performed of session.exercises) {
    const exercise = library.exercise(performed.exerciseID);
    if (!exercise) continue;
    for (const set of performed.sets) {
      if (counts(set))
        addTonnage(sessionTonnage, tonnage(set, exercise, session.bodyweight ?? null));
    }
  }
  return {
    localDate: sessionDate(session),
    exerciseCount: session.exercises.length,
    totalSets: sets.length,
    completedSets: sets.filter(isCompleted).length,
    workingSets: sets.filter(counts).length,
    duration: Math.max(0, (end - Date.parse(session.startedAt)) / 1000),
    tonnage: sessionTonnage,
    muscles: volumeByMuscle([session], library),
  };
}

// ---- History ----

const byStartThenID = (a, b) => {
  const difference = Date.parse(a.startedAt) - Date.parse(b.startedAt);
  if (difference !== 0) return difference;
  return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
};

/** The analysable view of finished sessions, like ExerlyCore's TrainingHistory. */
class TrainingHistory {
  constructor(sessions, library) {
    this.library = library;
    this.sessions = [...sessions].sort(byStartThenID);
    this.setsByExercise = new Map();
    for (const session of this.sessions) {
      const date = sessionDate(session);
      for (const performed of session.exercises) {
        for (const set of performed.sets) {
          if (!counts(set)) continue;
          if (!this.setsByExercise.has(performed.exerciseID)) {
            this.setsByExercise.set(performed.exerciseID, []);
          }
          this.setsByExercise.get(performed.exerciseID).push({
            sessionID: session.id,
            performedID: performed.id,
            date,
            sessionStart: Date.parse(session.startedAt),
            set,
            bodyweight: session.bodyweight ?? null,
          });
        }
      }
    }
  }

  session(id) {
    return this.sessions.find((session) => session.id === id) ?? null;
  }

  /** Completed working sets, oldest first, within an optional inclusive date range. */
  sets(exerciseID, from = null, through = null) {
    const all = this.setsByExercise.get(exerciseID) ?? [];
    return all.filter(
      (record) =>
        (from === null || record.date >= from) && (through === null || record.date <= through)
    );
  }

  statistics(exerciseID, from = null, through = null) {
    const exercise = this.library.exercise(exerciseID);
    if (!exercise) return null;
    const sets = this.sets(exerciseID, from, through);
    return sets.length === 0 ? null : statistics(exercise, sets);
  }

  /** The best e1RM of each session that has one, oldest first. */
  oneRepMaxTrend(exerciseID) {
    const exercise = this.library.exercise(exerciseID);
    if (!exercise) return [];
    const trend = [];
    for (const record of this.sets(exerciseID)) {
      const e1rm = setOneRepMax(record.set, exercise, record.bodyweight);
      if (e1rm === null) continue;
      const last = trend.at(-1);
      if (last && last.sessionID === record.sessionID)
        last.oneRepMax = Math.max(last.oneRepMax, e1rm);
      else trend.push({ date: record.date, sessionID: record.sessionID, oneRepMax: e1rm });
    }
    return trend;
  }

  /** Records set in `session` against every session that started earlier. */
  records(session) {
    const records = [];
    const seen = new Set();
    const start = Date.parse(session.startedAt);
    const bodyweight = session.bodyweight ?? null;
    for (const performed of session.exercises) {
      if (seen.has(performed.exerciseID)) continue;
      seen.add(performed.exerciseID);
      const exercise = this.library.exercise(performed.exerciseID);
      if (!exercise) continue;
      const earlier = this.sets(exercise.id).filter(
        (r) => r.sessionStart < start && r.sessionID !== session.id
      );
      if (earlier.length === 0) continue;
      const current = session.exercises
        .filter((p) => p.exerciseID === exercise.id)
        .flatMap((p) => p.sets)
        .filter(counts);
      const measures = [
        ['oneRepMax', (set, body) => setOneRepMax(set, exercise, body)],
        [
          'heaviestLoad',
          (set, body) =>
            LOAD_METRICS.has(exercise.metric) ? effectiveLoad(primary(set), exercise, body) : null,
        ],
        [
          'setVolume',
          (set, body) => {
            const t = tonnage(set, exercise, body);
            return REP_METRICS.has(exercise.metric) && t.isComplete && total(t) > 0
              ? total(t)
              : null;
          },
        ],
        [
          'duration',
          (set) =>
            DURATION_METRICS.has(exercise.metric) && sum(set, 'duration') > 0
              ? sum(set, 'duration')
              : null,
        ],
        [
          'distance',
          (set) =>
            DISTANCE_METRICS.has(exercise.metric) && sum(set, 'distance') > 0
              ? sum(set, 'distance')
              : null,
        ],
      ];
      for (const [kind, measure] of measures) {
        const earlierValues = earlier
          .map((r) => measure(r.set, r.bodyweight))
          .filter((value) => value !== null);
        if (earlierValues.length === 0) continue;
        const previous = Math.max(...earlierValues);
        let top = null;
        for (const set of current) {
          const value = measure(set, bodyweight);
          if (value !== null && (top === null || value > top.value)) top = { set, value };
        }
        if (top === null || !(top.value > previous + 1e-9)) continue;
        records.push({
          kind,
          exerciseID: exercise.id,
          sessionID: session.id,
          setID: top.set.id,
          value: top.value,
          previous,
          load: null,
        });
      }
      if (!REP_METRICS.has(exercise.metric)) continue;
      let repRecords = [];
      for (const set of current) {
        const reps = primary(set).reps;
        const load = effectiveLoad(primary(set), exercise, bodyweight);
        if (reps == null || load === null || !(load > 0)) continue;
        const earlierReps = earlier
          .filter((r) => {
            const earlierLoad = effectiveLoad(primary(r.set), exercise, r.bodyweight);
            return earlierLoad !== null && earlierLoad >= load - 1e-9;
          })
          .map((r) => primary(r.set).reps)
          .filter((value) => value != null);
        if (earlierReps.length === 0) continue;
        const previous = Math.max(...earlierReps);
        // One record per load: the set with the most reps.
        if (reps > previous && !repRecords.some((r) => r.load === load && r.value >= reps)) {
          repRecords = repRecords.filter((r) => r.load !== load);
          repRecords.push({
            kind: 'repsAtLoad',
            exerciseID: exercise.id,
            sessionID: session.id,
            setID: set.id,
            value: reps,
            previous,
            load,
          });
        }
      }
      records.push(...repRecords);
    }
    return records;
  }

  /** Volume per muscle for each week, keyed by the week's first local date. */
  weeklyMuscleVolume(firstWeekday) {
    const weeks = {};
    for (const session of this.sessions) {
      const week = startOfWeek(sessionDate(session), firstWeekday);
      accumulate(session, this.library, (weeks[week] ??= {}));
    }
    return weeks;
  }

  /** Volume per muscle for sessions whose local date is in the inclusive range. */
  muscleVolume(from, through) {
    return volumeByMuscle(
      this.sessions.filter((s) => {
        const date = sessionDate(s);
        return date >= from && date <= through;
      }),
      this.library
    );
  }
}

// ---- Metric references ----

/** Recomputes a metric reference: verified within 0.5 % or 0.01, mismatch, or unverifiable. */
function verifyMetric(reference, history) {
  const actual = computeMetric(reference, history);
  if (actual === null || actual === undefined) return { status: 'unverifiable', actual: null };
  const tolerance = Math.max(0.01, Math.abs(actual) * 0.005);
  return {
    status: Math.abs(actual - reference.claimed) <= tolerance ? 'verified' : 'mismatch',
    actual,
  };
}

function computeMetric({ name, parameters = {} }, history) {
  switch (name) {
    case 'exercise.e1rm.best':
    case 'exercise.volume.total': {
      const from = parseLocalDate(parameters.from);
      const through = parseLocalDate(parameters.through);
      if (typeof parameters.exercise !== 'string' || !from || !through) return null;
      const stats = history.statistics(parameters.exercise, from, through);
      if (!stats) return null;
      return name === 'exercise.e1rm.best' ? stats.estimatedOneRepMax : stats.totalVolume;
    }
    case 'muscle.sets.week': {
      const week = parseLocalDate(parameters.week);
      const weekday = /^\d+$/.test(parameters.firstWeekday ?? '')
        ? Number(parameters.firstWeekday)
        : NaN;
      if (!MUSCLES.includes(parameters.muscle) || !week || !(weekday >= 1 && weekday <= 7))
        return null;
      return history.weeklyMuscleVolume(weekday)[week]?.[parameters.muscle]?.sets ?? 0;
    }
    default:
      return null;
  }
}

module.exports = {
  TrainingHistory,
  kilograms,
  estimateOneRepMax,
  effectiveLoad,
  tonnage,
  total,
  setCredit,
  setOneRepMax,
  summary,
  sessionDate,
  startOfWeek,
  parseLocalDate,
  localDate,
  verifyMetric,
  counts,
};
