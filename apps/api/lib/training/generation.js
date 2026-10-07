// Program generation, ported from ExerlyCore's ProgramGeneration.swift so an
// agent can ask Exerly for a program rather than invent one. The Swift suite
// writes docs/api/golden/program-generation-v1.json and
// tests/training.generation.test.js holds this port to it. See
// docs/design/017-program-generation.md.

const { randomUUID } = require('node:crypto');

const GOALS = ['hypertrophy', 'strength', 'general'];
const EXPERIENCE = ['beginner', 'intermediate', 'advanced'];
const LARGER = [
  'chest',
  'lats',
  'midBack',
  'quads',
  'hamstrings',
  'glutes',
  'sideDelts',
  'biceps',
  'triceps',
];
const SMALLER = ['rearDelts', 'calves', 'abs'];
const SKILLED = new Set(['pistol-squat', 'handstand-push-up', 'nordic-hamstring-curl']);

/** Each movement pattern's exercises in order of preference. */
function exercisesFor(pattern, goal) {
  switch (pattern) {
    case 'squat':
      return [
        'back-squat',
        'hack-squat',
        'leg-press',
        'front-squat',
        'smith-machine-squat',
        'belt-squat',
        'goblet-squat',
        'bulgarian-split-squat',
        'dumbbell-reverse-lunge',
        'pistol-squat',
        'bodyweight-squat',
      ];
    case 'hinge':
      return [
        ...(goal === 'strength'
          ? ['deadlift', 'romanian-deadlift']
          : ['romanian-deadlift', 'deadlift']),
        'trap-bar-deadlift',
        'dumbbell-romanian-deadlift',
        'barbell-hip-thrust',
        'single-leg-romanian-deadlift',
        'cable-pull-through',
        'good-morning',
        'back-extension',
        'glute-bridge',
      ];
    case 'singleLeg':
      return [
        'bulgarian-split-squat',
        'dumbbell-reverse-lunge',
        'dumbbell-walking-lunge',
        'dumbbell-step-up',
        'pistol-squat',
      ];
    case 'horizontalPush':
      return [
        'barbell-bench-press',
        'dumbbell-bench-press',
        'machine-chest-press',
        'smith-machine-bench-press',
        'push-up',
        'kneeling-push-up',
      ];
    case 'inclinePush':
      return [
        'incline-dumbbell-bench-press',
        'incline-barbell-bench-press',
        'dip',
        'feet-elevated-push-up',
      ];
    case 'verticalPush':
      return [
        'overhead-press',
        'seated-dumbbell-shoulder-press',
        'machine-shoulder-press',
        'landmine-press',
        'pike-push-up',
        'handstand-push-up',
      ];
    case 'verticalPull':
      return ['pull-up', 'lat-pulldown', 'chin-up', 'close-grip-lat-pulldown'];
    case 'horizontalPull':
      return [
        'barbell-row',
        'chest-supported-dumbbell-row',
        'seated-cable-row',
        'one-arm-dumbbell-row',
        'machine-row',
        't-bar-row',
        'inverted-row',
      ];
    case 'chestFly':
      return ['cable-fly', 'dumbbell-fly', 'machine-fly'];
    case 'lateralRaise':
      return ['dumbbell-lateral-raise', 'cable-lateral-raise', 'machine-lateral-raise'];
    case 'rearDelt':
      return ['face-pull', 'dumbbell-reverse-fly', 'reverse-machine-fly'];
    case 'curl':
      return [
        'dumbbell-curl',
        'barbell-curl',
        'cable-curl',
        'incline-dumbbell-curl',
        'hammer-curl',
        'ez-bar-curl',
        'preacher-curl',
      ];
    case 'triceps':
      return [
        'triceps-pushdown',
        'overhead-dumbbell-triceps-extension',
        'skull-crusher',
        'overhead-cable-triceps-extension',
        'close-grip-bench-press',
        'bench-dip',
      ];
    case 'legExtension':
      return ['leg-extension'];
    case 'legCurl':
      return ['lying-leg-curl', 'seated-leg-curl', 'nordic-hamstring-curl'];
    case 'calfRaise':
      return [
        'standing-calf-raise',
        'seated-calf-raise',
        'leg-press-calf-raise',
        'single-leg-calf-raise',
      ];
    case 'abs':
      return ['cable-crunch', 'hanging-leg-raise', 'crunch', 'ab-wheel-rollout'];
  }
  throw new Error(`Unknown pattern ${pattern}`);
}

/** The pattern to use when a gym has nothing for this one. */
const FALLBACK = {
  squat: 'singleLeg',
  singleLeg: 'squat',
  legExtension: 'singleLeg',
  legCurl: 'hinge',
  inclinePush: 'horizontalPush',
  triceps: 'horizontalPush',
  chestFly: 'inclinePush',
  horizontalPush: 'inclinePush',
  verticalPush: 'inclinePush',
  lateralRaise: 'verticalPush',
  horizontalPull: 'verticalPull',
  curl: 'verticalPull',
  verticalPull: 'horizontalPull',
  rearDelt: 'horizontalPull',
};

function split(days) {
  const fullA = [
    'squat',
    'horizontalPush',
    'verticalPull',
    'legCurl',
    'lateralRaise',
    'triceps',
    'abs',
  ];
  const fullB = [
    'hinge',
    'verticalPush',
    'horizontalPull',
    'singleLeg',
    'chestFly',
    'curl',
    'calfRaise',
  ];
  const fullC = [
    'squat',
    'inclinePush',
    'horizontalPull',
    'legCurl',
    'rearDelt',
    'curl',
    'triceps',
  ];
  const upperA = [
    'horizontalPush',
    'verticalPull',
    'verticalPush',
    'horizontalPull',
    'lateralRaise',
    'triceps',
    'curl',
  ];
  const upperB = [
    'inclinePush',
    'horizontalPull',
    'verticalPull',
    'chestFly',
    'lateralRaise',
    'rearDelt',
    'curl',
    'triceps',
  ];
  const lowerA = ['squat', 'hinge', 'legExtension', 'legCurl', 'calfRaise', 'abs'];
  const lowerB = ['hinge', 'singleLeg', 'legCurl', 'legExtension', 'calfRaise', 'abs'];
  const push = [
    'horizontalPush',
    'verticalPush',
    'inclinePush',
    'lateralRaise',
    'triceps',
    'chestFly',
  ];
  const pull = ['verticalPull', 'horizontalPull', 'horizontalPull', 'rearDelt', 'curl', 'curl'];
  const legs = ['squat', 'hinge', 'singleLeg', 'legCurl', 'legExtension', 'calfRaise', 'abs'];
  switch (days) {
    case 2:
      return [
        'Full body',
        [
          ['Full body A', fullA],
          ['Full body B', fullB],
        ],
      ];
    case 3:
      return [
        'Full body',
        [
          ['Full body A', fullA],
          ['Full body B', fullB],
          ['Full body C', fullC],
        ],
      ];
    case 4:
      return [
        'Upper/Lower',
        [
          ['Upper A', upperA],
          ['Lower A', lowerA],
          ['Upper B', upperB],
          ['Lower B', lowerB],
        ],
      ];
    case 5:
      return [
        'Upper/Lower and Push/Pull/Legs',
        [
          ['Upper', upperA],
          ['Lower', lowerA],
          ['Push', push],
          ['Pull', pull],
          ['Legs', legs],
        ],
      ];
    default:
      return [
        'Push/Pull/Legs',
        [
          ['Push A', push],
          ['Pull A', pull],
          ['Legs A', legs],
          ['Push B', push],
          ['Pull B', pull],
          ['Legs B', legs],
        ],
      ];
  }
}

/** Problems with a request, as ExerlyCore words them. */
function requestProblems({ daysPerWeek, minutes }) {
  const problems = [];
  if (!(Number.isInteger(daysPerWeek) && daysPerWeek >= 2 && daysPerWeek <= 6))
    problems.push('Choose 2 to 6 training days a week');
  if (!(Number.isInteger(minutes) && minutes >= 30 && minutes <= 150))
    problems.push('Sessions must be 30 to 150 minutes');
  return problems;
}

/** Weekly fractional sets for each muscle with a target. */
function targetsFor({ goal, experience, emphasis = [] }) {
  const level = EXPERIENCE.indexOf(experience);
  const [big, small] = {
    hypertrophy: [
      [10, 14, 18],
      [6, 8, 10],
    ],
    strength: [
      [8, 10, 12],
      [4, 6, 6],
    ],
    general: [
      [8, 10, 12],
      [4, 6, 8],
    ],
  }[goal];
  const targets = new Map();
  for (const muscle of LARGER) targets.set(muscle, big[level]);
  for (const muscle of SMALLER) targets.set(muscle, small[level]);
  for (const muscle of emphasis)
    if (targets.has(muscle)) targets.set(muscle, Math.round(targets.get(muscle) * 1.3));
  return targets;
}

/** ExerlyCore's GymProfile.allows: everything it needs is here, and it isn't excluded. */
function allows(gym, exercise) {
  const available = new Set([...gym.equipment, 'bodyweight']);
  return (
    !(gym.excluded ?? []).includes(exercise.id) &&
    [...exercise.equipment, ...exercise.support].every((item) => available.has(item))
  );
}

function slotTarget(goal, exercise, sets, main) {
  const isolation = exercise.mechanics === 'isolation';
  const target = (minReps, maxReps, rir) => ({ sets, minReps, maxReps, rir, kind: 'standard' });
  if (goal === 'hypertrophy') return isolation ? target(10, 15, 1) : target(6, 10, 2);
  if (goal === 'strength') {
    if (isolation) return target(8, 12, 2);
    return main ? target(3, 5, 2) : target(5, 8, 2);
  }
  return isolation ? target(10, 15, 2) : target(8, 12, 2);
}

function weeklySets(days, library) {
  const weekly = new Map();
  for (const slot of days.flatMap((day) => day.slots)) {
    for (const [muscle, credit] of Object.entries(library.exercise(slot.exerciseID)?.muscles ?? {}))
      weekly.set(muscle, (weekly.get(muscle) ?? 0) + credit * slot.target.sets);
  }
  return weekly;
}

/** Compares two tuples as Swift does: element by element. */
function tupleLess(a, b) {
  for (let i = 0; i < a.length; i++) {
    if (a[i] < b[i]) return true;
    if (a[i] > b[i]) return false;
  }
  return false;
}
const byLess = (less) => (a, b) => (less(a, b) ? -1 : less(b, a) ? 1 : 0);

/**
 * Moves sets toward the targets: trims days over the cap, then adds a set
 * where a muscle is furthest under target and removes one where it is
 * furthest over, isolation work first, 2 to 5 sets an exercise.
 */
function balance(days, targets, cap, library) {
  const setsIn = (day) => day.slots.reduce((sum, slot) => sum + slot.target.sets, 0);
  // A day's main lift keeps at least 3 sets.
  const floor = (slot) => (slot === 0 ? 3 : 2);
  const isIsolation = ([d, s]) =>
    library.exercise(days[d].slots[s].exerciseID)?.mechanics === 'isolation';
  const isolationFirst = (a, b) => {
    const first = isIsolation(a);
    const second = isIsolation(b);
    return first !== second ? first : tupleLess(a, b);
  };
  for (const day of days) {
    while (setsIn(day) > cap) {
      let slot = -1;
      for (let i = day.slots.length - 1; i >= 0; i--)
        if (day.slots[i].target.sets > floor(i)) {
          slot = i;
          break;
        }
      if (slot >= 0) day.slots[slot].target.sets -= 1;
      else day.slots.pop();
    }
  }
  const keys = [...targets.keys()];
  for (let round = 0; round < 300; round++) {
    const weekly = weeklySets(days, library);
    const ratio = (muscle) => (weekly.get(muscle) ?? 0) / targets.get(muscle);
    const slotsTraining = (muscle) =>
      days
        .flatMap((day, d) =>
          day.slots
            .map((slot, s) => [d, s, slot])
            .filter(([, , slot]) => library.exercise(slot.exerciseID)?.muscles[muscle] === 1)
            .map(([d, s]) => [d, s])
        )
        .sort(byLess(isolationFirst));
    // The lowest ratio among the muscles a slot targets, after taking a set from it.
    const afterTaking = (d, s) => {
      const muscles = Object.entries(library.exercise(days[d].slots[s].exerciseID)?.muscles ?? {});
      const ratios = muscles
        .filter(([muscle, credit]) => credit === 1 && targets.has(muscle))
        .map(([muscle]) => ((weekly.get(muscle) ?? 0) - 1) / targets.get(muscle));
      return ratios.length ? Math.min(...ratios) : Infinity;
    };
    let changed = false;
    // The neediest muscle gains a set: with room in the day, or from a slot in
    // the same day whose muscles stay better served after.
    const needy = [...keys].sort(byLess((a, b) => tupleLess([ratio(a), a], [ratio(b), b])));
    for (const muscle of needy) {
      if (!(ratio(muscle) < 0.95)) continue;
      const gain = ratio(muscle) + 1 / targets.get(muscle);
      for (const [d, s] of slotsTraining(muscle)) {
        if (!(days[d].slots[s].target.sets < 5)) continue;
        if (setsIn(days[d]) < cap) {
          days[d].slots[s].target.sets += 1;
          changed = true;
        } else {
          const donor = days[d].slots.findIndex(
            (other, o) => o !== s && other.target.sets > floor(o) && afterTaking(d, o) > gain + 1e-9
          );
          if (donor >= 0) {
            days[d].slots[donor].target.sets -= 1;
            days[d].slots[s].target.sets += 1;
            changed = true;
          }
        }
        if (changed) break;
      }
      if (changed) break;
    }
    // Otherwise an over-served muscle, most over first, gives up a set, or a
    // whole exercise (never a main lift) when every muscle it targets stays at
    // target and trained on two days without it.
    // Most over first; ties by name.
    const over = [...keys].sort(byLess((a, b) => tupleLess([ratio(b), a], [ratio(a), b])));
    for (const high of over) {
      if (changed || !(ratio(high) > 1.3)) continue;
      const candidates = slotsTraining(high);
      const reducible = candidates.find(([d, s]) => days[d].slots[s].target.sets > floor(s));
      if (reducible) {
        const [d, s] = reducible;
        days[d].slots[s].target.sets -= 1;
        changed = true;
        continue;
      }
      const removable = candidates.find(([d, s]) => {
        const slot = days[d].slots[s];
        const muscles = Object.entries(library.exercise(slot.exerciseID)?.muscles ?? {}).filter(
          ([muscle]) => targets.has(muscle)
        );
        // Still at target, and still trained on two days.
        return (
          s > 0 &&
          muscles.every(
            ([muscle, credit]) =>
              ((weekly.get(muscle) ?? 0) - credit * slot.target.sets) / targets.get(muscle) >= 1 &&
              (credit < 1 ||
                new Set(
                  slotsTraining(muscle)
                    .filter(([od, os]) => !(od === d && os === s))
                    .map(([od]) => od)
                ).size >= 2)
          )
        );
      });
      if (removable) {
        days[removable[0]].slots.splice(removable[1], 1);
        changed = true;
      }
    }
    if (!changed) break;
  }
}

/**
 * A program for the request, using only exercises `gym` allows (all of them
 * without a gym). The program has fresh IDs, as ExerlyCore's would. Returns
 * `{ problems }` for a request out of range.
 */
function generate(request, library, { gym = null, createdAt = new Date(), id = randomUUID } = {}) {
  const problems = requestProblems(request);
  if (problems.length) return { problems };
  const { daysPerWeek, goal, experience, minutes } = request;
  const targets = targetsFor(request);
  const [splitName, plan] = split(daysPerWeek);
  const cap = Math.floor(minutes / 3);
  const usable = (exerciseID) => {
    const exercise = library.exercise(exerciseID);
    if (!exercise || (experience === 'beginner' && SKILLED.has(exerciseID))) return null;
    return !gym || allows(gym, exercise) ? exercise : null;
  };
  // Each pattern's n-th appearance in the cycle takes its n-th usable
  // exercise, for variety; a strength program keeps each day's main lift.
  const seen = new Map();
  const days = plan.map(([name, patterns]) => {
    const slots = [];
    patterns.forEach((pattern, position) => {
      let options = [];
      const tried = new Set();
      let current = pattern;
      while (options.length === 0 && current && !tried.has(current)) {
        tried.add(current);
        options = exercisesFor(current, goal)
          .map(usable)
          .filter((option) => option && !slots.some((slot) => slot.exerciseID === option.id));
        current = FALLBACK[current];
      }
      const occurrence = seen.get(pattern) ?? 0;
      seen.set(pattern, occurrence + 1);
      if (options.length === 0) return;
      const exercise =
        options[goal === 'strength' && position === 0 ? 0 : occurrence % options.length];
      const sets = goal === 'strength' && slots.length === 0 ? 4 : 3;
      slots.push({
        exerciseID: exercise.id,
        target: slotTarget(goal, exercise, sets, slots.length === 0),
      });
    });
    return { name, slots };
  });
  balance(days, targets, cap, library);
  const weekly = weeklySets(days, library);
  const shortfalls = [...targets]
    .filter(([muscle, target]) => (weekly.get(muscle) ?? 0) < 0.8 * target)
    .map(([muscle, target]) => [(weekly.get(muscle) ?? 0) / target, muscle])
    .sort(byLess(tupleLess))
    .map(([, muscle]) => muscle);
  const program = {
    id: id(),
    name: `${daysPerWeek}-day ${splitName}`,
    days: days.map((day) => ({
      id: id(),
      name: day.name,
      slots: day.slots.map((slot) => ({
        id: id(),
        exerciseID: slot.exerciseID,
        notes: '',
        target: slot.target,
        cycleTargets: {},
        expandRepRange: false,
        weightMatch: true,
      })),
    })),
    cycles: 6,
    deload: experience === 'beginner' ? 'none' : 'last',
    createdAt: createdAt.toISOString(),
  };
  return {
    program,
    weeklySets: Object.fromEntries(weekly),
    targets: Object.fromEntries(targets),
    shortfalls,
  };
}

module.exports = { GOALS, EXPERIENCE, generate, requestProblems, targetsFor, allows };
