/**
 * Exercise library — 45 exercises with equipment tags.
 * Used by WizardService to generate personalized workout plans.
 */

export const exercises = [
  // ─── Compound — Barbell ───
  { id: 'bb_squat', name: 'Barbell Squat', muscles: ['quads', 'glutes', 'core'], equipment: ['barbell'], cat: 'compound' },
  { id: 'bb_bench', name: 'Bench Press', muscles: ['chest', 'triceps', 'shoulders'], equipment: ['barbell', 'bench'], cat: 'compound' },
  { id: 'bb_deadlift', name: 'Deadlift', muscles: ['back', 'glutes', 'hamstrings'], equipment: ['barbell'], cat: 'compound' },
  { id: 'bb_ohp', name: 'Overhead Press', muscles: ['shoulders', 'triceps'], equipment: ['barbell'], cat: 'compound' },
  { id: 'bb_row', name: 'Barbell Row', muscles: ['back', 'biceps'], equipment: ['barbell'], cat: 'compound' },
  { id: 'bb_rdl', name: 'Romanian Deadlift', muscles: ['hamstrings', 'glutes'], equipment: ['barbell'], cat: 'compound' },
  { id: 'bb_hip_thrust', name: 'Hip Thrust', muscles: ['glutes', 'hamstrings'], equipment: ['barbell', 'bench'], cat: 'compound' },
  { id: 'bb_front_squat', name: 'Front Squat', muscles: ['quads', 'core'], equipment: ['barbell'], cat: 'compound' },

  // ─── Compound — Dumbbells ───
  { id: 'db_bench', name: 'Dumbbell Bench Press', muscles: ['chest', 'triceps'], equipment: ['dumbbells', 'bench'], cat: 'compound' },
  { id: 'db_row', name: 'Dumbbell Row', muscles: ['back', 'biceps'], equipment: ['dumbbells'], cat: 'compound' },
  { id: 'db_shoulder', name: 'Dumbbell Shoulder Press', muscles: ['shoulders', 'triceps'], equipment: ['dumbbells'], cat: 'compound' },
  { id: 'db_lunge', name: 'Dumbbell Lunges', muscles: ['quads', 'glutes'], equipment: ['dumbbells'], cat: 'compound' },
  { id: 'db_rdl', name: 'Dumbbell RDL', muscles: ['hamstrings', 'glutes'], equipment: ['dumbbells'], cat: 'compound' },
  { id: 'db_goblet', name: 'Goblet Squat', muscles: ['quads', 'glutes', 'core'], equipment: ['dumbbells'], cat: 'compound' },

  // ─── Compound — Bodyweight ───
  { id: 'pushup', name: 'Push-Up', muscles: ['chest', 'triceps', 'shoulders'], equipment: ['bodyweight'], cat: 'compound' },
  { id: 'pullup', name: 'Pull-Up', muscles: ['back', 'biceps'], equipment: ['pull_up_bar'], cat: 'compound' },
  { id: 'chinup', name: 'Chin-Up', muscles: ['back', 'biceps'], equipment: ['pull_up_bar'], cat: 'compound' },
  { id: 'dip', name: 'Dips', muscles: ['chest', 'triceps'], equipment: ['bodyweight'], cat: 'compound' },
  { id: 'inv_row', name: 'Inverted Row', muscles: ['back', 'biceps'], equipment: ['bodyweight'], cat: 'compound' },
  { id: 'pike_push', name: 'Pike Push-Up', muscles: ['shoulders', 'triceps'], equipment: ['bodyweight'], cat: 'compound' },
  { id: 'bw_squat', name: 'Bodyweight Squat', muscles: ['quads', 'glutes'], equipment: ['bodyweight'], cat: 'compound' },
  { id: 'step_up', name: 'Step-Up', muscles: ['quads', 'glutes'], equipment: ['bodyweight'], cat: 'compound' },

  // ─── Compound — Cables/Machines ───
  { id: 'cable_row', name: 'Cable Row', muscles: ['back', 'biceps'], equipment: ['cables'], cat: 'compound' },
  { id: 'lat_pull', name: 'Lat Pulldown', muscles: ['back', 'biceps'], equipment: ['cables'], cat: 'compound' },
  { id: 'leg_press', name: 'Leg Press', muscles: ['quads', 'glutes'], equipment: ['machines'], cat: 'compound' },
  { id: 'chest_press', name: 'Machine Chest Press', muscles: ['chest', 'triceps'], equipment: ['machines'], cat: 'compound' },

  // ─── Isolation ───
  { id: 'db_curl', name: 'Dumbbell Curl', muscles: ['biceps'], equipment: ['dumbbells'], cat: 'isolation' },
  { id: 'tri_push', name: 'Tricep Pushdown', muscles: ['triceps'], equipment: ['cables'], cat: 'isolation' },
  { id: 'lat_raise', name: 'Lateral Raise', muscles: ['shoulders'], equipment: ['dumbbells'], cat: 'isolation' },
  { id: 'leg_curl', name: 'Leg Curl', muscles: ['hamstrings'], equipment: ['machines'], cat: 'isolation' },
  { id: 'leg_ext', name: 'Leg Extension', muscles: ['quads'], equipment: ['machines'], cat: 'isolation' },
  { id: 'face_pull', name: 'Face Pull', muscles: ['shoulders', 'back'], equipment: ['cables'], cat: 'isolation' },
  { id: 'fly', name: 'Dumbbell Fly', muscles: ['chest'], equipment: ['dumbbells', 'bench'], cat: 'isolation' },
  { id: 'band_pull', name: 'Band Pull-Apart', muscles: ['shoulders', 'back'], equipment: ['resistance_bands'], cat: 'isolation' },
  { id: 'band_curl', name: 'Band Curl', muscles: ['biceps'], equipment: ['resistance_bands'], cat: 'isolation' },

  // ─── Core ───
  { id: 'plank', name: 'Plank', muscles: ['core'], equipment: ['bodyweight'], cat: 'compound' },
  { id: 'dead_bug', name: 'Dead Bug', muscles: ['core'], equipment: ['bodyweight'], cat: 'isolation' },
  { id: 'hanging_leg', name: 'Hanging Leg Raise', muscles: ['core'], equipment: ['pull_up_bar'], cat: 'isolation' },

  // ─── Cardio ───
  { id: 'burpee', name: 'Burpees', muscles: ['full_body'], equipment: ['bodyweight'], cat: 'cardio' },
  { id: 'mt_climb', name: 'Mountain Climbers', muscles: ['core', 'cardio'], equipment: ['bodyweight'], cat: 'cardio' },
  { id: 'jump_rope', name: 'Jump Rope', muscles: ['cardio'], equipment: ['bodyweight'], cat: 'cardio' },
  { id: 'treadmill', name: 'Treadmill Run', muscles: ['cardio'], equipment: ['cardio_machines'], cat: 'cardio' },
  { id: 'bike', name: 'Stationary Bike', muscles: ['cardio', 'quads'], equipment: ['cardio_machines'], cat: 'cardio' },
  { id: 'jump_squat', name: 'Jump Squat', muscles: ['quads', 'glutes', 'cardio'], equipment: ['bodyweight'], cat: 'cardio' },

  // ─── Kettlebells ───
  { id: 'kb_swing', name: 'Kettlebell Swing', muscles: ['glutes', 'hamstrings', 'core'], equipment: ['kettlebells'], cat: 'compound' },
  { id: 'kb_goblet', name: 'Kettlebell Goblet Squat', muscles: ['quads', 'glutes'], equipment: ['kettlebells'], cat: 'compound' },
];

// ─── Helpers ───
function hasEquip(ex, avail) {
  return ex.equipment.some((e) => avail.includes(e));
}

function pickN(arr, n) {
  const shuffled = [...arr].sort(() => Math.random() - 0.5);
  return shuffled.slice(0, n);
}

function scheme(goal) {
  switch (goal) {
    case 'lose_weight': return { sets: 3, reps: '12-15', rest: 60 };
    case 'build_muscle': return { sets: 4, reps: '8-12', rest: 90 };
    case 'improve_endurance': return { sets: 3, reps: '15-20', rest: 45 };
    default: return { sets: 3, reps: '10-12', rest: 75 };
  }
}

// ─── Split logic ───
function getSplit(daysPerWeek) {
  if (daysPerWeek <= 2) return ['Full Body', 'Full Body'];
  if (daysPerWeek === 3) return ['Push', 'Pull', 'Legs'];
  if (daysPerWeek === 4) return ['Upper', 'Lower', 'Upper', 'Lower'];
  if (daysPerWeek === 5) return ['Push', 'Pull', 'Legs', 'Upper', 'Lower'];
  return ['Push', 'Pull', 'Legs', 'Push', 'Pull', 'Legs'];
}

const PUSH_MUSCLES = ['chest', 'shoulders', 'triceps'];
const PULL_MUSCLES = ['back', 'biceps'];
const LEG_MUSCLES = ['quads', 'glutes', 'hamstrings'];

function musclesForSplit(split) {
  switch (split) {
    case 'Push': return PUSH_MUSCLES;
    case 'Pull': return PULL_MUSCLES;
    case 'Legs': return LEG_MUSCLES;
    case 'Upper': return [...PUSH_MUSCLES, ...PULL_MUSCLES];
    case 'Lower': return LEG_MUSCLES;
    default: return [...PUSH_MUSCLES, ...PULL_MUSCLES, ...LEG_MUSCLES];
  }
}

// ─── Generate plan ───
export function generateWorkoutPlan(state) {
  const avail = state.equipment ?? ['bodyweight'];
  const days = state.workoutsPerWeek ?? 3;
  const goal = state.primaryGoal ?? 'maintain';
  const split = getSplit(days);
  const rep = scheme(goal);
  const DAYS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

  const plan = {};
  let splitIdx = 0;

  if (days <= 0) {
    DAYS.forEach((day) => {
      plan[day] = { type: 'Rest', exercises: [] };
    });
    return plan;
  }

  // Distribute workout days evenly
  const spacing = Math.floor(7 / days);
  const workoutDayIndices = [];
  for (let i = 0; i < days; i++) {
    workoutDayIndices.push(Math.min(i * spacing, 6));
  }

  DAYS.forEach((day, i) => {
    if (workoutDayIndices.includes(i) && splitIdx < split.length) {
      const splitType = split[splitIdx];
      const muscles = musclesForSplit(splitType);
      const pool = exercises.filter((e) => hasEquip(e, avail) && e.muscles.some((m) => muscles.includes(m)));
      const compounds = pickN(pool.filter((e) => e.cat === 'compound'), 3);
      const isos = pickN(pool.filter((e) => e.cat === 'isolation'), 2);
      const cardio = goal === 'lose_weight' || goal === 'improve_endurance'
        ? pickN(exercises.filter((e) => e.cat === 'cardio' && hasEquip(e, avail)), 1)
        : [];
      const selected = [...compounds, ...isos, ...cardio].map((e) => ({
        id: e.id,
        name: e.name,
        sets: rep.sets,
        reps: rep.reps,
        restSeconds: rep.rest,
      }));
      plan[day] = { type: splitType, exercises: selected };
      splitIdx++;
    } else {
      plan[day] = { type: 'Rest', exercises: [] };
    }
  });

  return plan;
}
