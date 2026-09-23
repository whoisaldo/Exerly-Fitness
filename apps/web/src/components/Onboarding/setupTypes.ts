import type { SessionUser } from '../../hooks/useSession';

export interface SetupTargets {
  calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  fiber_g?: number;
}

export interface SetupAnswers {
  [key: string]: unknown;
  name: string;
  age: number;
  gender: string;
  sex: string | null;
  height: number;
  weight: number;
  goal: string;
  nutritionGoal: string;
  targetWeight: number | null;
  activityLevel: string;
  targetMode: string;
  manualTargets: SetupTargets | null;
  timezone: string;
  unitSystem: 'metric' | 'imperial';
  experienceLevel: string;
  workoutDaysPerWeek: number;
  equipmentAccess: string;
  equipment: string[];
  activityTypes: string[];
  dietaryStyle: string;
  allergies: string[];
  mealsPerDay: number;
  sleepGoalHours: number;
  bedtime: string | null;
  wakeTime: string | null;
  workoutDays: string[];
  timelineWeeks: number;
  reminders: Record<string, boolean>;
}

export interface SetupStatus {
  complete: boolean;
  needs_repair: boolean;
  user: SessionUser;
  targets: SetupTargets | null;
  repair_answers?: Partial<SetupAnswers>;
  repair_reason?: string;
}

export interface SetupPreview {
  targets: SetupTargets;
  maintenance: number | null;
}
export interface SetupContent {
  schema_version: 2;
  last_valid_step: number;
  answers: SetupAnswers;
}
export interface RemoteSetupDraft {
  account_id: string;
  schema_version: number;
  last_valid_step: number;
  revision: number;
  answers: Partial<SetupAnswers>;
}

export const fitnessGoals = [
  ['lose_weight', 'Lose weight'],
  ['gain_muscle', 'Build muscle'],
  ['maintain', 'Maintain fitness'],
  ['improve_endurance', 'Improve endurance'],
  ['general_health', 'General health'],
] as const;
export const activityLevels = [
  ['sedentary', 'Mostly seated'],
  ['light', 'Lightly active'],
  ['moderate', 'Moderately active'],
  ['active', 'Active'],
  ['very_active', 'Very active'],
] as const;

function normalizeAnswers(raw: Partial<SetupAnswers>, defaults: SetupAnswers): SetupAnswers {
  const answers = { ...defaults };
  for (const [key, value] of Object.entries(raw)) {
    if (value == null && defaults[key] != null) continue;
    const expected = defaults[key];
    if (
      Array.isArray(expected) &&
      (!Array.isArray(value) || value.some((item) => typeof item !== 'string'))
    )
      throw new Error(
        'The saved setup contains an unsupported answer. Your drafts have been kept.'
      );
    if (expected != null && !Array.isArray(expected) && typeof value !== typeof expected)
      throw new Error(
        'The saved setup contains an unsupported answer. Your drafts have been kept.'
      );
    answers[key] = value;
  }
  const goals: Record<string, string> = {
    lose: 'lose_weight',
    weight_loss: 'lose_weight',
    gain: 'gain_muscle',
    muscle_gain: 'gain_muscle',
  };
  const activities: Record<string, string> = {
    lightly_active: 'light',
    moderately_active: 'moderate',
    'very active': 'very_active',
  };
  answers.goal = goals[answers.goal] ?? answers.goal;
  answers.activityLevel = activities[answers.activityLevel] ?? answers.activityLevel;
  if (!raw.nutritionGoal)
    answers.nutritionGoal =
      answers.goal === 'lose_weight'
        ? 'lose'
        : answers.goal === 'gain_muscle'
          ? 'gain'
          : 'maintain';
  return answers;
}

export function initialAnswers(user: SessionUser, repair?: Partial<SetupAnswers>): SetupAnswers {
  const answers: SetupAnswers = {
    name: user.name ?? '',
    age: user.age ?? 0,
    gender: user.gender ?? '',
    sex: null,
    height: user.height ?? 0,
    weight: user.weight ?? 0,
    goal: user.goal ?? '',
    nutritionGoal: 'maintain',
    targetWeight: user.targetWeight ?? null,
    activityLevel: user.activityLevel ?? '',
    targetMode: 'estimated',
    manualTargets: null,
    timezone: user.timezone,
    unitSystem: user.unitSystem,
    experienceLevel: 'beginner',
    workoutDaysPerWeek: 3,
    equipmentAccess: 'bodyweight',
    equipment: [],
    activityTypes: [],
    dietaryStyle: 'standard',
    allergies: [],
    mealsPerDay: 3,
    sleepGoalHours: 8,
    bedtime: null,
    wakeTime: null,
    workoutDays: [],
    timelineWeeks: 12,
    reminders: {},
  };
  return normalizeAnswers(repair ?? {}, answers);
}

export function normalizeContent(remote: RemoteSetupDraft, defaults: SetupAnswers): SetupContent {
  const answers = normalizeAnswers(remote.answers, defaults);
  let step = remote.last_valid_step;
  if (remote.schema_version === 1)
    step = step <= 1 ? 0 : step <= 3 ? 1 : step === 4 ? 2 : step <= 9 ? 3 : 4;
  return { schema_version: 2, answers, last_valid_step: Math.max(0, Math.min(4, step)) };
}

const within = (n: number, min: number, max: number) => Number.isFinite(n) && n >= min && n <= max;
export function setupError(answers: SetupAnswers, step: number): string | null {
  const a = answers;
  if (step === 0 && (!a.name.trim() || a.name.trim().length > 80))
    return 'Enter your name, up to 80 characters.';
  if (step === 1) {
    if (!Number.isInteger(a.age) || !within(a.age, 18, 120))
      return 'Enter an age from 18 to 120. Exerly currently supports adults.';
    if (!a.gender || a.gender.length > 32) return 'Choose a gender identity, or prefer not to say.';
    if (!within(a.height, 50, 280) || !within(a.weight, 20, 500))
      return 'Enter a valid height and weight.';
    if (!['manual', 'estimated'].includes(a.targetMode))
      return 'Choose how to set your daily targets.';
    if (a.targetMode !== 'manual' && !['female', 'male'].includes(a.sex ?? ''))
      return 'Choose a calculation parameter or enter your own targets.';
    if (a.targetMode === 'manual') {
      const t = a.manualTargets;
      if (
        !t ||
        !within(t.calories, 800, 10000) ||
        !within(t.protein_g, 0, 500) ||
        !within(t.carbs_g, 0, 1500) ||
        !within(t.fat_g, 0, 500) ||
        !within(t.fiber_g ?? 30, 0, 100)
      )
        return 'Enter valid calorie and nutrient targets.';
    }
  }
  if (step === 2) {
    if (!fitnessGoals.some(([value]) => value === a.goal)) return 'Choose a fitness goal.';
    if (!['lose', 'maintain', 'gain'].includes(a.nutritionGoal)) return 'Choose a nutrition goal.';
    if (a.nutritionGoal !== 'maintain') {
      if (a.targetWeight == null || !within(a.targetWeight, 20, 500))
        return 'Enter a target weight.';
      if (a.nutritionGoal === 'lose' && a.targetWeight > a.weight)
        return 'Your target weight must not exceed your current weight.';
      if (a.nutritionGoal === 'gain' && a.targetWeight < a.weight)
        return 'Your target weight must not be below your current weight.';
    }
  }
  if (step === 3) {
    if (!activityLevels.some(([value]) => value === a.activityLevel))
      return 'Choose your usual activity level.';
    try {
      if (!a.timezone) throw new Error();
      new Intl.DateTimeFormat('en', { timeZone: a.timezone });
    } catch {
      return 'Enter a valid time zone, such as America/New_York.';
    }
  }
  return null;
}

export function firstIncomplete(content: SetupContent): number {
  return [0, 1, 2, 3].find((step) => setupError(content.answers, step)) ?? 4;
}

export function contentSignature(value: unknown): string {
  return JSON.stringify(value, (_key, item) =>
    item && typeof item === 'object' && !Array.isArray(item)
      ? Object.fromEntries(
          Object.keys(item)
            .sort()
            .map((key) => [key, item[key]])
        )
      : item
  );
}
