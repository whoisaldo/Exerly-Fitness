// Whether a payload is a document ExerlyCore would accept, mirroring its
// decoders, WorkoutSession.validate(library:) and Exercise.validationErrors.
// MCP checks a proposal's documents with this, so a person never reviews a
// proposal their phone can't apply. Each function returns a list of problems.

const { MUSCLES } = require('./library');

const UUID_RE = /^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$/;
const ISO_RE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,9})?(Z|[+-]\d{2}:\d{2})$/;
const SET_KINDS = ['warmUp', 'standard', 'drop', 'myo', 'failure'];
const METRICS = [
  'weightReps',
  'bodyweightReps',
  'assistedReps',
  'duration',
  'weightDuration',
  'distanceDuration',
  'weightDistance',
];

const isNumber = (value) => typeof value === 'number' && Number.isFinite(value);
const isInstant = (value) =>
  typeof value === 'string' && ISO_RE.test(value) && !Number.isNaN(Date.parse(value));

function validTimeZone(zone) {
  try {
    new Intl.DateTimeFormat('en', { timeZone: zone });
    return true;
  } catch {
    return false;
  }
}

function massProblem(mass, where) {
  if (mass == null) return null;
  if (typeof mass !== 'object' || !['kg', 'lb'].includes(mass.unit) || !isNumber(mass.value))
    return `${where} must be {"value": number, "unit": "kg" or "lb"}`;
  if (mass.value < 0) return `${where} cannot be negative`;
  return null;
}

/** What a completed set of this metric must record, as ExerlyCore's isLoggable checks. */
function loggable(effort, metric) {
  const duration = (effort.duration ?? 0) > 0;
  const distance = (effort.distance ?? 0) > 0;
  if (
    ['weightReps', 'bodyweightReps', 'assistedReps'].includes(metric) &&
    !((effort.reps ?? 0) >= 1)
  )
    return false;
  if (['weightReps', 'weightDuration', 'weightDistance'].includes(metric) && effort.load == null)
    return false;
  if (metric === 'duration' || metric === 'weightDuration') return duration;
  if (metric === 'distanceDuration') return duration || distance;
  if (metric === 'weightDistance') return distance;
  return true;
}

function setProblems(set, exercise, where) {
  const problems = [];
  if (!set || typeof set !== 'object') return [`${where} must be an object`];
  if (!UUID_RE.test(set.id ?? '')) problems.push(`${where}.id must be a UUID`);
  if (!SET_KINDS.includes(set.kind)) problems.push(`${where}.kind must be one of ${SET_KINDS}`);
  if (set.side != null && !['left', 'right'].includes(set.side))
    problems.push(`${where}.side must be left or right`);
  if (set.rir != null && !(isNumber(set.rir) && set.rir >= 0 && set.rir <= 6))
    problems.push(`${where}.rir must be from 0 to 6`);
  if (set.completedAt != null && !isInstant(set.completedAt))
    problems.push(`${where}.completedAt must be an ISO 8601 instant`);
  if (!Array.isArray(set.efforts) || set.efforts.length === 0) {
    problems.push(`${where}.efforts needs at least one effort`);
    return problems;
  }
  if (set.efforts.length > 1 && !['drop', 'myo'].includes(set.kind))
    problems.push(`${where} has several efforts, which only drop and myo sets allow`);
  set.efforts.forEach((effort, i) => {
    const at = `${where}.efforts[${i}]`;
    if (effort.reps != null && !(Number.isInteger(effort.reps) && effort.reps >= 0))
      problems.push(`${at}.reps must be a whole number of 0 or more`);
    const mass = massProblem(effort.load, `${at}.load`);
    if (mass) problems.push(mass);
    for (const field of ['duration', 'distance']) {
      if (effort[field] != null && !(isNumber(effort[field]) && effort[field] >= 0))
        problems.push(`${at}.${field} must be a number of 0 or more`);
    }
  });
  if (problems.length === 0 && exercise && set.completedAt != null) {
    if (!set.efforts.every((effort) => loggable(effort, exercise.metric)))
      problems.push(`${where} is completed without the values ${exercise.name} records`);
  }
  return problems;
}

/** Problems with a workout_session payload, or an empty list. */
function sessionProblems(session, id, library) {
  const problems = [];
  if (!session || typeof session !== 'object') return ['The session must be an object'];
  if (session.id !== id || !UUID_RE.test(id)) problems.push('id must be the document ID, a UUID');
  if (typeof session.name !== 'string') problems.push('name must be a string');
  if (typeof session.notes !== 'string') problems.push('notes must be a string');
  if (!isInstant(session.startedAt)) problems.push('startedAt must be an ISO 8601 instant');
  if (session.endedAt != null) {
    if (!isInstant(session.endedAt)) problems.push('endedAt must be an ISO 8601 instant');
    else if (Date.parse(session.endedAt) < Date.parse(session.startedAt))
      problems.push('endedAt is before startedAt');
  }
  if (typeof session.timeZoneID !== 'string' || !validTimeZone(session.timeZoneID))
    problems.push('timeZoneID must be an IANA time zone');
  const mass = massProblem(session.bodyweight, 'bodyweight');
  if (mass) problems.push(mass);
  if (!Array.isArray(session.exercises)) return [...problems, 'exercises must be an array'];
  const seen = new Set();
  session.exercises.forEach((performed, e) => {
    const where = `exercises[${e}]`;
    if (!performed || typeof performed !== 'object')
      return problems.push(`${where} must be an object`);
    if (!UUID_RE.test(performed.id ?? '')) problems.push(`${where}.id must be a UUID`);
    else if (seen.has(performed.id.toUpperCase())) problems.push(`${where}.id is used twice`);
    else seen.add(performed.id.toUpperCase());
    if (typeof performed.notes !== 'string') problems.push(`${where}.notes must be a string`);
    if (performed.supersetID != null && !UUID_RE.test(performed.supersetID))
      problems.push(`${where}.supersetID must be a UUID`);
    if (performed.restOverride != null && !isNumber(performed.restOverride))
      problems.push(`${where}.restOverride must be a number of seconds`);
    const exercise = library.exercise(performed.exerciseID);
    if (!exercise)
      problems.push(`${where}.exerciseID ${performed.exerciseID} is not a known exercise`);
    if (!Array.isArray(performed.sets)) return problems.push(`${where}.sets must be an array`);
    performed.sets.forEach((set, s) => {
      if (set?.id && UUID_RE.test(set.id)) {
        if (seen.has(set.id.toUpperCase())) problems.push(`${where}.sets[${s}].id is used twice`);
        seen.add(set.id.toUpperCase());
      }
      problems.push(...setProblems(set, exercise, `${where}.sets[${s}]`));
    });
  });
  return problems;
}

/** Problems with a custom_exercise payload, mirroring Exercise.validationErrors. */
function customExerciseProblems(exercise, id) {
  const problems = [];
  if (!exercise || typeof exercise !== 'object') return ['The exercise must be an object'];
  if (exercise.id !== id || !id.startsWith('custom-'))
    problems.push('id must be the document ID and start with "custom-"');
  if (typeof exercise.name !== 'string' || exercise.name.trim() === '')
    problems.push('name is empty');
  if (!METRICS.includes(exercise.metric)) problems.push(`metric must be one of ${METRICS}`);
  if (!['compound', 'isolation'].includes(exercise.mechanics))
    problems.push('mechanics must be compound or isolation');
  if (!['upper', 'lower', 'core', 'fullBody'].includes(exercise.region))
    problems.push('region must be upper, lower, core or fullBody');
  const muscles = exercise.muscles ?? {};
  if (Object.keys(muscles).some((m) => !MUSCLES.includes(m))) problems.push('unknown muscle');
  if (Object.values(muscles).some((share) => !(share > 0 && share <= 1)))
    problems.push('muscle shares must be in (0, 1]');
  const category = exercise.category ?? 'strength';
  const equipment = exercise.equipment ?? [];
  if (category === 'strength') {
    if (!Object.values(muscles).includes(1))
      problems.push('a strength exercise needs a target muscle');
    if (equipment.length === 0) problems.push('a strength exercise needs equipment');
  }
  const share = exercise.bodyweight ?? 0;
  if (!(share >= 0 && share <= 1)) problems.push('bodyweight share must be in [0, 1]');
  if (['bodyweightReps', 'assistedReps'].includes(exercise.metric)) {
    if (share === 0 && exercise.metric === 'assistedReps')
      problems.push('an assisted exercise needs a bodyweight share');
  } else if (share !== 0) {
    problems.push('only bodyweight metrics take a bodyweight share');
  }
  if (
    ['weightReps', 'weightDuration', 'weightDistance'].includes(exercise.metric) &&
    equipment.includes('bodyweight')
  )
    problems.push('an external-load metric cannot use bodyweight as equipment');
  if (exercise.metric === 'bodyweightReps' && !equipment.includes('bodyweight'))
    problems.push('a bodyweight exercise lists bodyweight as equipment');
  return problems;
}

module.exports = { sessionProblems, customExerciseProblems, UUID_RE };
