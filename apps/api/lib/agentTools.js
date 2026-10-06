// What a person's own agent can do with their training data: read it through
// the same calculations as the app, and file proposals the person decides on.
// MCP exposes these as tools (routes/mcp.js). Every number comes from
// lib/training, which matches ExerlyCore exactly; none comes from a model.

const { randomUUID } = require('node:crypto');
const store = require('../data');
const docs = require('./documents');
const { canonicalJSON } = require('./mutations');
const { badRequest, forbidden, notFound } = require('./errors');
const { ExerciseLibrary } = require('./training/library');
const training = require('./training/history');
const { sessionProblems, customExerciseProblems, programProblems } = require('./training/validate');
const progression = require('./training/progression');
const dates = require('./dates');
const nutritionTools = require('./nutritionTools');

const DATA_KINDS = ['workout_session', 'custom_exercise', 'program'];
const EVIDENCE_LEVELS = ['humanRCT', 'observational', 'mechanism', 'anecdote', 'personalData'];
const WEEKDAYS = { sunday: 1, monday: 2 };

/** The bundled library plus the account's custom exercises. */
async function accountLibrary(account) {
  const rows = await store.find('documents', {
    account_id: account.id,
    kind: 'custom_exercise',
    deleted_at: null,
  });
  return ExerciseLibrary.withCustom(rows.map((row) => row.payload));
}

/**
 * Problems with a training document an agent wants written, checked as
 * ExerlyCore would check it before applying it.
 */
function trainingProblems(kind, id, payload, library) {
  if (kind === 'workout_session') return sessionProblems(payload, id, library);
  if (kind === 'custom_exercise') return customExerciseProblems(payload, id);
  if (kind === 'program') return programProblems(payload, id, library);
  return [`${kind} is not a training document`];
}

/** An account's training data, loaded once per request. */
async function workspace(account) {
  const rows = await store.find('documents', {
    account_id: account.id,
    kind: { in: [...DATA_KINDS, 'proposal', ...nutritionTools.KINDS] },
    deleted_at: null,
  });
  const of = (kind) => rows.filter((row) => row.kind === kind).map((row) => row.payload);
  const library = ExerciseLibrary.withCustom(of('custom_exercise'));
  const sessions = of('workout_session');
  return {
    account,
    library,
    sessions,
    customExercises: of('custom_exercise'),
    programs: of('program'),
    proposals: of('proposal'),
    nutrition: nutritionTools.prepare(of),
    history: new training.TrainingHistory(
      sessions.filter((s) => s.endedAt),
      library
    ),
  };
}

const round = (value, places = 2) =>
  value === null || value === undefined ? null : Math.round(value * 10 ** places) / 10 ** places;

function tonnageView(tonnage) {
  return {
    total_kg_reps: round(training.total(tonnage), 1),
    bodyweight_kg_reps: round(tonnage.bodyweight, 1),
    complete: tonnage.isComplete,
  };
}

function musclesView(muscles) {
  return Object.entries(muscles)
    .map(([muscle, volume]) => ({
      muscle,
      sets: round(volume.sets, 2),
      volume: tonnageView(volume.tonnage),
    }))
    .sort((a, b) => b.sets - a.sets || a.muscle.localeCompare(b.muscle));
}

function readDate(value, name) {
  if (value == null || value === '') return null;
  const date = training.parseLocalDate(value);
  if (!date) throw badRequest(`${name} must be a date written YYYY-MM-DD`);
  return date;
}

function resolveExercise(ws, query) {
  const direct = ws.library.exercise(query);
  if (direct) return direct;
  const [best] = ws.library.search(String(query));
  if (!best) throw notFound(`No exercise matches "${query}". Try search_exercises.`);
  return best;
}

function sessionSummary(ws, session) {
  const summary = training.summary(session, ws.library, new Date());
  return {
    id: session.id,
    name: session.name,
    date: summary.localDate,
    started_at: session.startedAt,
    ended_at: session.endedAt ?? null,
    in_progress: !session.endedAt,
    time_zone: session.timeZoneID,
    duration_min: round(summary.duration / 60, 1),
    exercises: session.exercises.map(
      (p) => ws.library.exercise(p.exerciseID)?.name ?? p.exerciseID
    ),
    working_sets: summary.workingSets,
    volume: tonnageView(summary.tonnage),
  };
}

const mass = (m) =>
  m ? { value: m.value, unit: m.unit, kg: round(training.kilograms(m), 3) } : null;

// ---- Read tools ----

function profile(ws) {
  const timezone = dates.normalizeTimeZone(ws.account.timezone);
  return {
    name: ws.account.name ?? null,
    time_zone: timezone,
    today: training.localDate(new Date(), timezone),
    unit_system: ws.account.unitSystem ?? 'metric',
    units:
      'Loads are kilograms and volume is kilogram-reps unless a field says otherwise. Convert for display only.',
    finished_workouts: ws.history.sessions.length,
    first_workout: ws.history.sessions[0] ? training.sessionDate(ws.history.sessions[0]) : null,
    last_workout: ws.history.sessions.at(-1)
      ? training.sessionDate(ws.history.sessions.at(-1))
      : null,
    pending_proposals: ws.proposals.filter((p) => p.status === 'pending').length,
  };
}

function listWorkouts(ws, { from, through, limit = 20 } = {}) {
  const start = readDate(from, 'from');
  const end = readDate(through, 'through');
  const rows = ws.sessions
    .map((session) => ({ session, date: training.sessionDate(session) }))
    .filter(({ date }) => (!start || date >= start) && (!end || date <= end))
    .sort((a, b) => Date.parse(b.session.startedAt) - Date.parse(a.session.startedAt));
  return {
    total: rows.length,
    workouts: rows.slice(0, limit).map(({ session }) => sessionSummary(ws, session)),
  };
}

function getWorkout(ws, { id }) {
  const session = ws.sessions.find((s) => s.id.toUpperCase() === String(id).toUpperCase());
  if (!session) throw notFound('No workout has that ID');
  const summary = training.summary(session, ws.library, new Date());
  const bodyweight = session.bodyweight ?? null;
  return {
    ...sessionSummary(ws, session),
    notes: session.notes,
    bodyweight: mass(bodyweight),
    muscles: musclesView(summary.muscles),
    exercise_log: session.exercises.map((performed) => {
      const exercise = ws.library.exercise(performed.exerciseID);
      return {
        exercise_id: performed.exerciseID,
        name: exercise?.name ?? null,
        notes: performed.notes,
        sets: performed.sets.map((set) => ({
          id: set.id,
          kind: set.kind,
          side: set.side ?? null,
          completed: set.completedAt != null,
          rir: set.rir ?? null,
          efforts: set.efforts.map((effort) => ({
            reps: effort.reps ?? null,
            load: mass(effort.load),
            duration_s: effort.duration ?? null,
            distance_m: effort.distance ?? null,
          })),
          e1rm_kg: exercise ? round(training.setOneRepMax(set, exercise, bodyweight), 2) : null,
          counts_toward_volume: exercise ? training.setCredit(set, exercise) : 0,
        })),
      };
    }),
    records: session.endedAt
      ? ws.history.records(session).map((r) => ({
          kind: r.kind,
          exercise_id: r.exerciseID,
          set_id: r.setID,
          value: round(r.value, 2),
          previous: round(r.previous, 2),
          load_kg: round(r.load, 2),
        }))
      : [],
  };
}

function exerciseHistory(ws, { exercise: query, from, through, recent_sets: recent = 20 }) {
  const exercise = resolveExercise(ws, query);
  const start = readDate(from, 'from');
  const end = readDate(through, 'through');
  const stats = ws.history.statistics(exercise.id, start, end);
  const sets = ws.history.sets(exercise.id, start, end);
  return {
    exercise: { id: exercise.id, name: exercise.name, metric: exercise.metric },
    range: { from: start, through: end },
    statistics: stats && {
      e1rm_kg: round(stats.estimatedOneRepMax),
      e3rm_kg: round(stats.estimatedThreeRepMax),
      e10rm_kg: round(stats.estimatedTenRepMax),
      heaviest_load_kg: round(stats.heaviestLoad),
      total_volume_kg_reps: round(stats.totalVolume, 1),
      volume_complete: stats.isVolumeComplete,
      best_set_volume_kg_reps: round(stats.bestSetVolume, 1),
      total_reps: stats.totalReps,
      best_set_reps: stats.bestSetReps,
      total_duration_s: stats.totalDuration,
      best_set_duration_s: stats.bestSetDuration,
      total_distance_m: stats.totalDistance,
      best_set_distance_m: stats.bestSetDistance,
      total_sets: stats.totalSets,
    },
    e1rm_trend: ws.history
      .oneRepMaxTrend(exercise.id)
      .filter((p) => (!start || p.date >= start) && (!end || p.date <= end))
      .map((p) => ({ date: p.date, workout_id: p.sessionID, e1rm_kg: round(p.oneRepMax) })),
    recent_sets: sets
      .slice(-recent)
      .reverse()
      .map((r) => ({
        date: r.date,
        workout_id: r.sessionID,
        set_id: r.set.id,
        kind: r.set.kind,
        reps: r.set.efforts[0]?.reps ?? null,
        load: mass(r.set.efforts[0]?.load),
        rir: r.set.rir ?? null,
        e1rm_kg: round(training.setOneRepMax(r.set, exercise, r.bodyweight)),
      })),
  };
}

function weeklyVolume(ws, { weeks = 8, first_weekday: firstWeekday = 'monday', through } = {}) {
  const weekday = WEEKDAYS[firstWeekday];
  if (!weekday) throw badRequest('first_weekday must be monday or sunday');
  const end =
    readDate(through, 'through') ??
    training.localDate(new Date(), dates.normalizeTimeZone(ws.account.timezone));
  const lastWeek = training.startOfWeek(end, weekday);
  const all = ws.history.weeklyMuscleVolume(weekday);
  const result = [];
  for (let i = 0; i < weeks; i++) {
    const week = new Date(Date.parse(`${lastWeek}T00:00:00Z`) - i * 7 * 86_400_000)
      .toISOString()
      .slice(0, 10);
    result.push({ week_starting: week, muscles: musclesView(all[week] ?? {}) });
  }
  return {
    first_weekday: firstWeekday,
    note: 'Sets are fractional: a target muscle counts 1 per working set, a synergist 0.5, one side of a unilateral exercise half.',
    weeks: result,
  };
}

function searchExercises(ws, { query = '', muscle, limit = 15 }) {
  return {
    exercises: ws.library
      .search(query, { muscle })
      .slice(0, limit)
      .map((e) => ({
        id: e.id,
        name: e.name,
        aliases: e.aliases,
        metric: e.metric,
        laterality: e.laterality,
        target_muscles: Object.keys(e.muscles).filter((m) => e.muscles[m] === 1),
        synergists: Object.keys(e.muscles).filter((m) => e.muscles[m] < 1),
        equipment: e.equipment,
        custom: e.id.startsWith('custom-'),
      })),
  };
}

function listProposals(ws, { status, limit = 20 } = {}) {
  return {
    proposals: ws.proposals
      .filter((p) => !status || p.status === status)
      .sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt))
      .slice(0, limit)
      .map((p) => ({
        id: p.id,
        title: p.title,
        status: p.status,
        author: p.author,
        created_at: p.createdAt,
        decided_at: p.decidedAt ?? null,
        confidence: p.confidence,
        changes: p.changes.map((c) => ({ kind: c.kind, id: c.id })),
      })),
  };
}

// ---- Programs ----

function activeProgram(ws) {
  return (
    ws.programs
      .filter((p) => p.activatedAt && !p.archivedAt)
      .sort((a, b) => Date.parse(b.activatedAt) - Date.parse(a.activatedAt))[0] ?? null
  );
}

function programProgress(ws, program) {
  const done = new Set(
    ws.history.sessions
      .filter((s) => s.program?.programID === program.id)
      .map((s) => `${s.program.cycle}/${s.program.dayID}`)
  ).size;
  const total = progression.trainingDays(program).length * program.cycles;
  return { done: Math.min(done, total), total };
}

function listPrograms(ws) {
  const active = activeProgram(ws);
  return {
    programs: [...ws.programs]
      .sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt))
      .map((program) => ({
        id: program.id,
        name: program.name,
        active: program.id === active?.id,
        archived: !!program.archivedAt,
        cycles: program.cycles,
        deload: program.deload,
        progress: programProgress(ws, program),
        days: program.days.map((day) => ({
          id: day.id,
          name: day.name,
          rest: day.slots.length === 0,
          exercises: day.slots.map(
            (slot) => ws.library.exercise(slot.exerciseID)?.name ?? slot.exerciseID
          ),
        })),
      })),
  };
}

/** The next workout of a program, with each exercise's recommendation. */
function nextWorkout(ws, { program_id: programID } = {}) {
  const program = programID
    ? ws.programs.find((p) => p.id === docs.canonicalID(programID))
    : activeProgram(ws);
  if (!program) throw notFound(programID ? 'No program has that ID' : 'No program is active');
  const position = progression.nextPosition(program, ws.history.sessions);
  const summary = { id: program.id, name: program.name, progress: programProgress(ws, program) };
  if (!position) return { program: summary, complete: true };
  const bodyweight =
    [...ws.history.sessions].reverse().find((s) => s.bodyweight)?.bodyweight ?? null;
  return {
    program: summary,
    day: position.day.name,
    cycle: position.cycle + 1,
    deload: position.isDeload,
    exercises: position.day.slots.flatMap((slot) => {
      const exercise = ws.library.exercise(slot.exerciseID);
      if (!exercise) return [];
      const target = progression.targetFor(program, slot, position.cycle);
      const plan = progression.recommend(target, exercise, ws.history.sets(exercise.id), {
        bodyweight,
        expandRepRange: slot.expandRepRange,
      });
      return [
        {
          exercise_id: exercise.id,
          name: exercise.name,
          notes: slot.notes,
          target: {
            sets: target.sets,
            reps: `${target.minReps}-${target.maxReps}`,
            rir: target.rir,
            rest_s: target.rest ?? null,
          },
          recommendation: {
            reason: plan.reason,
            e1rm_kg: round(plan.oneRepMax),
            outside_rep_range: plan.outsideRange,
            sets: plan.sets.map((s) => ({
              kind: s.kind,
              reps: s.effort.reps ?? null,
              load: mass(s.effort.load),
              rir: s.rir,
            })),
          },
        },
      ];
    }),
  };
}

function getDocument(ws, { kind, id }) {
  if (!DATA_KINDS.includes(kind)) throw badRequest(`kind must be ${DATA_KINDS.join(' or ')}`);
  const documents = {
    workout_session: ws.sessions,
    custom_exercise: ws.customExercises,
    program: ws.programs,
  };
  const payload = documents[kind].find((document) => document.id === docs.canonicalID(id));
  if (!payload) throw notFound(`No ${kind} has that ID`);
  return { kind, id, payload };
}

function verifyMetric(ws, reference) {
  return training.verifyMetric(reference, ws.history);
}

// ---- Proposals ----

function readEvidence(items, ws) {
  if (!Array.isArray(items)) return [];
  return items.map((item, i) => {
    if (!item || typeof item.claim !== 'string' || item.claim.trim() === '')
      throw badRequest(`evidence[${i}] needs a claim`);
    if (!EVIDENCE_LEVELS.includes(item.level))
      throw badRequest(`evidence[${i}].level must be one of ${EVIDENCE_LEVELS.join(', ')}`);
    const evidence = {
      claim: item.claim,
      level: item.level,
      caveats: (item.caveats ?? []).map(String),
      dataRefs: (item.dataRefs ?? []).map((ref) => ({
        kind: String(ref.kind),
        id: docs.canonicalID(String(ref.id)),
      })),
    };
    if (item.source) evidence.source = String(item.source);
    if (item.metric) {
      const { name, parameters = {}, claimed } = item.metric;
      if (typeof name !== 'string' || typeof claimed !== 'number')
        throw badRequest(`evidence[${i}].metric needs a name and a claimed number`);
      const stringParameters = Object.fromEntries(
        Object.entries(parameters).map(([key, value]) => [key, String(value)])
      );
      evidence.metric = { name, parameters: stringParameters, claimed };
      evidence.verification = training.verifyMetric(evidence.metric, ws.history);
    }
    return evidence;
  });
}

/**
 * Files a pending proposal. The server fills each change's `before` from the
 * stored document, so a proposal always describes the data as it is now.
 */
async function propose(ws, pat, input) {
  if (!pat.scopes.includes('propose') && !pat.scopes.includes('write'))
    throw forbidden('This token can read but not file proposals');
  const { title, summary = '', confidence, falsifier } = input;
  if (typeof title !== 'string' || title.trim() === '')
    throw badRequest('A proposal needs a title');
  if (typeof falsifier !== 'string' || falsifier.trim() === '')
    throw badRequest('A proposal needs a falsifier: what would show it is wrong');
  if (!['low', 'medium', 'high'].includes(confidence))
    throw badRequest('confidence must be low, medium or high');
  if (!Array.isArray(input.changes) || input.changes.length === 0)
    throw badRequest('A proposal needs at least one change');
  const evidence = readEvidence(input.evidence, ws);
  const changes = [];
  for (const [i, change] of input.changes.entries()) {
    const kind = change?.kind;
    if (!DATA_KINDS.includes(kind))
      throw badRequest(`changes[${i}].kind must be ${DATA_KINDS.join(' or ')}`);
    const id = docs.readID(String(change.id ?? ''));
    const current = await docs.current(ws.account, kind, id);
    const before = current && !current.deleted_at ? current.payload : null;
    const after = docs.canonicalPayload(kind, change.after ?? null);
    if (before === null && after === null)
      throw badRequest(`changes[${i}] deletes ${kind} ${id}, which doesn't exist`);
    if (after !== null) {
      const problems = trainingProblems(kind, id, after, ws.library);
      if (problems.length)
        throw badRequest(
          `changes[${i}] is not a valid ${kind}: ${problems.slice(0, 5).join('; ')}`
        );
    }
    if (before !== null && after !== null && canonicalJSON(before) === canonicalJSON(after))
      throw badRequest(`changes[${i}] doesn't change ${kind} ${id}`);
    changes.push({ kind, id, before, after });
  }
  const id = randomUUID().toUpperCase();
  const payload = {
    id,
    createdAt: new Date().toISOString(),
    author: docs.tokenActor(pat),
    title: title.trim(),
    summary,
    changes,
    evidence: evidence.map(({ verification: _verification, ...rest }) => rest),
    confidence,
    falsifier: falsifier.trim(),
    status: 'pending',
  };
  await store.transaction(async () => {
    const now = new Date();
    const row = await store.insert('documents', {
      account_id: ws.account.id,
      kind: 'proposal',
      document_id: id,
      revision: 1,
      payload,
      deleted_at: null,
      created_at: now,
      updated_at: now,
    });
    await docs.record(ws.account, row);
    await docs.appendAudit(ws.account, {
      action: 'proposalFiled',
      actor: payload.author,
      proposalID: id,
      targets: changes.map((c) => ({ kind: c.kind, id: c.id })),
    });
  });
  return {
    proposal_id: id,
    status: 'pending',
    message: 'Filed. Nothing changes until the person accepts it in Exerly.',
    evidence_checks: evidence
      .map((e, i) => (e.verification ? { evidence: i, ...e.verification } : null))
      .filter(Boolean),
  };
}

module.exports = {
  accountLibrary,
  trainingProblems,
  DATA_KINDS,
  workspace,
  profile,
  listWorkouts,
  getWorkout,
  exerciseHistory,
  weeklyVolume,
  searchExercises,
  listProposals,
  listPrograms,
  nextWorkout,
  getDocument,
  verifyMetric,
  propose,
  EVIDENCE_LEVELS,
};
