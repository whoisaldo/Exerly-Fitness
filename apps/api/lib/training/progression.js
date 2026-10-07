// Programs and RIR progression, ported line for line from ExerlyCore
// (Program.swift, Progression.swift). The golden file written by Swift checks
// every recommendation (tests/training.golden.test.js).

const training = require('./history');

const KILOGRAMS_PER_UNIT = { kg: 1, lb: 0.45359237 };
const REP_METRICS = new Set(['weightReps', 'bodyweightReps', 'assistedReps']);
const MAXIMUM_RISE = 0.05;
const MAXIMUM_CUT = 0.1;
const HOLD_BAND = 1;
const RECENT_SESSIONS = 4;

/** Reps to failure a load allows at an e1RM: the inverse of the estimate. */
function repsToFailure(load, oneRepMax) {
  if (!(load > 0) || !(oneRepMax > 0)) return 30;
  const brzycki = 37 - (36 * load) / oneRepMax;
  return brzycki <= 10 ? Math.max(1, brzycki) : (oneRepMax / load - 1) * 30;
}

const loadForReps = (reps, oneRepMax) =>
  reps <= 10 ? (oneRepMax * (37 - reps)) / 36 : oneRepMax / (1 + reps / 30);

/** Load steps for an exercise's resistance equipment. */
function defaultIncrements(exercise) {
  const has = (...names) => names.some((name) => exercise.equipment.includes(name));
  if (has('barbell', 'trapBar'))
    return { kilograms: 2.5, pounds: 5, minimum: { unit: 'kg', value: 20 } };
  if (has('ezBar')) return { kilograms: 2.5, pounds: 5, minimum: { unit: 'kg', value: 10 } };
  if (has('smithMachine', 'landmine')) return { kilograms: 2.5, pounds: 5 };
  if (has('dumbbell')) return { kilograms: 2, pounds: 5 };
  if (has('kettlebell')) return { kilograms: 4, pounds: 10 };
  if (has('cable', 'machine', 'sled')) return { kilograms: 5, pounds: 10 };
  return { kilograms: 1.25, pounds: 2.5 };
}

const targetRepsExact = (target) => (target.minReps + target.maxReps) / 2;
const valueIn = (mass, unit) =>
  mass.unit === unit ? mass.value : training.kilograms(mass) / KILOGRAMS_PER_UNIT[unit];

/** A set's RIR for its primary effort, as ExerlyCore's effectiveRIR. */
function effectiveRIR(set) {
  if (set.kind === 'failure') return 0;
  if (set.kind === 'drop' || set.kind === 'myo') return set.rir ?? 0;
  return set.rir ?? null;
}

/**
 * What progression recommends for a slot target, from the exercise's earlier
 * completed working sets (oldest first, as TrainingHistory.sets returns them).
 */
function recommend(
  target,
  exercise,
  records,
  { bodyweight = null, increments, expandRepRange = false } = {}
) {
  const steps = increments ?? defaultIncrements(exercise);
  const targetReps = Math.floor(targetRepsExact(target));
  const plan = (effort, reason, oneRepMax = null, basisSetID = null, outsideRange = false) => ({
    sets: Array.from({ length: target.sets }, () => ({
      kind: target.kind ?? 'standard',
      effort,
      rir: target.rir,
    })),
    reason,
    oneRepMax,
    basisSetID,
    outsideRange,
  });
  if (!REP_METRICS.has(exercise.metric)) {
    const last = records.at(-1)?.set.efforts[0] ?? {};
    return plan(last, records.length === 0 ? 'firstSession' : 'repeatLast');
  }
  const sessions = [];
  for (const record of records) {
    const rated = { ...record.set };
    if (rated.rir == null && rated.kind !== 'failure') rated.rir = target.rir;
    const e1rm = training.setOneRepMax(rated, exercise, record.bodyweight);
    if (e1rm === null) continue;
    const last = sessions.at(-1);
    if (last && last.id === record.sessionID) {
      if (e1rm > last.best)
        sessions[sessions.length - 1] = { id: record.sessionID, best: e1rm, record };
    } else {
      sessions.push({ id: record.sessionID, best: e1rm, record });
    }
  }
  const latest = sessions.at(-1);
  if (!latest) return plan({ reps: targetReps }, 'firstSession');
  const top = latest.record.set.efforts[0];
  const unit =
    top.load?.unit ??
    [...records].reverse().find((r) => r.set.efforts[0].load)?.set.efforts[0].load.unit ??
    'kg';
  const earlier = sessions.slice(0, -1).slice(-RECENT_SESSIONS);
  const previous = earlier.at(-1)?.best ?? null;
  let estimate = latest.best;
  if (earlier.length)
    estimate = Math.min(estimate, Math.max(...earlier.map((s) => s.best)) * (1 + MAXIMUM_RISE));
  let reason = 'progress';
  if (previous !== null) {
    const latestLoad = training.effectiveLoad(top, exercise, latest.record.bodyweight) ?? 0;
    const predicted = repsToFailure(latestLoad, previous);
    const achieved = (top.reps ?? 0) + (effectiveRIR(latest.record.set) ?? target.rir);
    if (estimate < previous && achieved < predicted - HOLD_BAND - 1e-9) {
      reason = 'reduce';
      estimate = Math.max(estimate, previous * (1 - MAXIMUM_CUT));
    } else if (estimate < previous) {
      const held = { reps: targetReps };
      if (top.load) held.load = top.load;
      return plan(held, 'hold', previous, latest.record.set.id);
    } else if (estimate === previous) {
      reason = 'hold';
    }
  }
  const weight = bodyweight ?? latest.record.bodyweight;
  const share =
    exercise.metric === 'bodyweightReps' && weight
      ? training.kilograms(weight) * exercise.bodyweightShare
      : 0;
  if (exercise.metric === 'assistedReps') {
    const repeat = { reps: targetReps };
    if (top.load) repeat.load = top.load;
    return plan(repeat, 'repeatLast', estimate, latest.record.set.id);
  }
  const aim = targetReps + target.rir;
  const ideal = loadForReps(aim, estimate) - share;
  const step = unit === 'kg' ? steps.kilograms : steps.pounds;
  const minimum = steps.minimum ? valueIn(steps.minimum, unit) : 0;
  const floorValue = exercise.metric === 'bodyweightReps' ? 0 : minimum;
  const base = Math.max(floorValue, Math.floor(ideal / KILOGRAMS_PER_UNIT[unit] / step) * step);
  const reps = (value) =>
    repsToFailure(value * KILOGRAMS_PER_UNIT[unit] + share, estimate) - target.rir;
  const candidates = [-3, -2, -1, 0, 1, 2, 3]
    .map((i) => base + i * step)
    .filter((v) => v >= floorValue);
  const mid = targetRepsExact(target);
  const choose = (lower, upper) => {
    let best = null;
    for (const value of candidates) {
      const exact = reps(value);
      const whole = Math.floor(exact);
      if (whole < lower || whole > upper) continue;
      const option = { value, whole, cost: Math.abs(whole - mid) + (exact - whole) * 0.5 };
      // Swift's min(by:) keeps the first of equals; ties go to the heavier load.
      const better =
        best === null ||
        (Math.abs(option.cost - best.cost) > 1e-9
          ? option.cost < best.cost
          : option.value > best.value);
      if (better) best = option;
    }
    return best;
  };
  let outside = false;
  let choice = choose(target.minReps, target.maxReps);
  if (choice === null && expandRepRange) {
    choice = choose(Math.max(1, target.minReps - 2), target.maxReps + 2);
    outside = choice !== null;
  }
  if (choice === null) {
    outside = true;
    const clamped = Math.floor(reps(base));
    choice = { value: base, whole: Math.min(Math.max(clamped, target.minReps), target.maxReps) };
  }
  const load =
    exercise.metric === 'bodyweightReps' && choice.value === 0
      ? null
      : { unit, value: choice.value };
  if (reason === 'progress' && top.reps != null) {
    const lastLoad = top.load ? training.kilograms(top.load) : 0;
    const newLoad = load ? training.kilograms(load) : 0;
    if (
      newLoad < lastLoad - 1e-9 ||
      (Math.abs(newLoad - lastLoad) < 1e-9 && choice.whole <= top.reps)
    ) {
      reason = 'hold';
    }
  }
  const effort = { reps: choice.whole };
  if (load) effort.load = load;
  return plan(effort, reason, estimate, latest.record.set.id, outside);
}

// ---- Programs ----

const trainingDays = (program) => program.days.filter((day) => day.slots.length > 0);

function isDeload(program, cycle) {
  if (program.cycles <= 1) return false;
  if (program.deload === 'first') return cycle === 0;
  if (program.deload === 'last') return cycle === program.cycles - 1;
  return false;
}

/** A slot's target in a cycle: its own, or the deload of its default. */
function targetFor(program, slot, cycle) {
  const specific = slot.cycleTargets?.[String(cycle)];
  if (specific) return specific;
  if (!isDeload(program, cycle)) return slot.target;
  return {
    ...slot.target,
    sets: Math.max(1, Math.floor((slot.target.sets + 1) / 2)),
    rir: Math.min(5, slot.target.rir + 2),
  };
}

/** The next training day after the latest session from this program, or null when done. */
function nextPosition(program, sessions) {
  const days = trainingDays(program);
  if (days.length === 0) return null;
  const last = [...sessions]
    .sort((a, b) => Date.parse(a.startedAt) - Date.parse(b.startedAt) || (a.id < b.id ? -1 : 1))
    .reverse()
    .find((s) => s.program?.programID === program.id);
  const index = last ? days.findIndex((d) => d.id === last.program.dayID) : -1;
  if (!last || index === -1) return { day: days[0], cycle: 0, isDeload: isDeload(program, 0) };
  let cycle = last.program.cycle;
  let next = index + 1;
  if (next === days.length) {
    next = 0;
    cycle += 1;
  }
  if (cycle >= program.cycles) return null;
  return { day: days[next], cycle, isDeload: isDeload(program, cycle) };
}

module.exports = {
  recommend,
  repsToFailure,
  defaultIncrements,
  targetFor,
  nextPosition,
  trainingDays,
  isDeload,
};
