import AsyncStorage from '@react-native-async-storage/async-storage';
import apiClient from '../api/client';
import { generateWorkoutPlan } from './ExerciseLibrary';
import {
  cancelAll,
  requestPermissions,
  scheduleDailyReminder,
  scheduleWeeklySummary,
  scheduleStreakAlert,
} from './NotificationService';

const PROGRESS_KEY = 'onboarding_progress';
const COMPLETE_KEY = 'onboarding_complete';
const PLAN_KEY = 'starter_workout_plan';

// ─── PAL multipliers ───
const PAL = {
  sedentary: 1.2,
  lightly_active: 1.375,
  moderately_active: 1.55,
  very_active: 1.725,
  athlete: 1.9,
};

// ─── BMR — Mifflin-St Jeor ───
export function calcBMR(weightKg, heightCm, age, gender) {
  const base = 10 * weightKg + 6.25 * heightCm - 5 * age;
  if (gender === 'male') return base + 5;
  if (gender === 'female') return base - 161;
  return base - 78; // average of male/female
}

// ─── TDEE ───
export function calcTDEE(bmr, fitnessLevel) {
  return Math.round(bmr * (PAL[fitnessLevel] ?? 1.55));
}

// ─── BMI ───
export function calcBMI(weightKg, heightCm) {
  const m = heightCm / 100;
  return +(weightKg / (m * m)).toFixed(1);
}

export function bmiCategory(bmi) {
  if (bmi < 18.5) return { label: 'Underweight', color: '#3b82f6' };
  if (bmi < 25) return { label: 'Normal', color: '#10b981' };
  if (bmi < 30) return { label: 'Overweight', color: '#f59e0b' };
  return { label: 'Obese', color: '#ef4444' };
}

// ─── Body fat — Deurenberg ───
export function estimateBodyFat(bmi, age, gender) {
  const g = gender === 'male' ? 1 : 0;
  const bf = 1.2 * bmi + 0.23 * age - 10.8 * g - 5.4;
  return { estimate: Math.round(bf), low: Math.round(bf - 3), high: Math.round(bf + 3) };
}

// ─── Healthy weight range ───
export function healthyWeightRange(heightCm) {
  const m = heightCm / 100;
  return {
    min: Math.round(18.5 * m * m),
    max: Math.round(24.9 * m * m),
  };
}

// ─── Calorie target ───
export function calcCalorieTarget(tdee, bmr, goal, weightKg) {
  const safetyFloor = Math.round(bmr * 1.1);
  let target;
  switch (goal) {
    case 'lose_weight':
      target = tdee - 500;
      break;
    case 'build_muscle':
      target = tdee + 300;
      break;
    case 'improve_endurance':
    case 'improve_health':
      target = tdee - 100;
      break;
    default:
      target = tdee;
  }
  return Math.max(Math.round(target), safetyFloor);
}

// ─── Macros — protein-first (MacroFactor approach) ───
export function calcMacros(targetCal, weightKg, goal, dietaryStyle, bfData) {
  const isKeto = dietaryStyle?.includes?.('keto');

  // Protein
  let proteinG;
  if (goal === 'lose_weight') {
    const leanMass = weightKg * (1 - (bfData?.estimate ?? 25) / 100);
    proteinG = Math.round(leanMass * 2.5);
  } else if (goal === 'build_muscle') {
    proteinG = Math.round(weightKg * 2.0);
  } else {
    proteinG = Math.round(weightKg * 1.6);
  }
  proteinG = Math.max(proteinG, 120);

  // Fat
  let fatPercent = 0.28;
  if (isKeto) fatPercent = 0.70;
  let fatG = Math.round((targetCal * fatPercent) / 9);
  fatG = Math.max(fatG, Math.round(weightKg * 0.7));

  // Carbs — remainder
  const proteinCal = proteinG * 4;
  const fatCal = fatG * 9;
  let carbG = Math.round((targetCal - proteinCal - fatCal) / 4);
  if (isKeto) carbG = Math.min(carbG, 40);
  carbG = Math.max(carbG, 0);

  return { protein: proteinG, carbs: carbG, fat: fatG };
}

// ─── Goal rate safety check ───
export function goalRateSafety(currentKg, targetKg, weeks) {
  if (!targetKg || !weeks) return { safe: true, label: 'healthy', weeklyKg: 0 };
  const totalKg = Math.abs(currentKg - targetKg);
  const weeklyKg = totalKg / weeks;
  const pct = (weeklyKg / currentKg) * 100;
  if (pct <= 0.5) return { safe: true, label: 'healthy', weeklyKg };
  if (pct <= 1.0) return { safe: true, label: 'aggressive', weeklyKg };
  return { safe: false, label: 'not recommended', weeklyKg };
}

// ─── Sleep recommendation copy ───
export function sleepCopy(hours) {
  if (hours < 6) return 'Below minimum for cognitive function';
  if (hours < 7) return 'Adequate but not ideal for recovery';
  if (hours <= 9) return 'Optimal for muscle recovery & hormone balance';
  return 'More than most people need — listen to your body';
}

// ─── Bedtime from wake time ───
export function calcBedtime(wakeTime, sleepHours) {
  const [h, m] = wakeTime.split(':').map(Number);
  const wakeMin = h * 60 + m;
  let bedMin = wakeMin - sleepHours * 60;
  if (bedMin < 0) bedMin += 1440;
  const bh = Math.floor(bedMin / 60) % 24;
  const bm = Math.round(bedMin % 60);
  return `${String(bh).padStart(2, '0')}:${String(bm).padStart(2, '0')}`;
}

// ─── Water goal ───
export function calcWaterGoal(weightKg) {
  return +(weightKg * 0.033).toFixed(1);
}

// ─── Unit conversions ───
export function lbsToKg(lbs) { return +(lbs * 0.453592).toFixed(1); }
export function kgToLbs(kg) { return +(kg * 2.20462).toFixed(1); }
export function ftInToCm(ft, inch) { return +((ft * 12 + inch) * 2.54).toFixed(1); }
export function cmToFtIn(cm) {
  const totalIn = cm / 2.54;
  let ft = Math.floor(totalIn / 12);
  let inch = Math.round(totalIn % 12);
  if (inch === 12) {
    ft += 1;
    inch = 0;
  }
  return { ft, in: inch };
}

// ─── Full calculation pipeline ───
export function calculateAll(state) {
  const bmr = calcBMR(state.weightKg, state.heightCm, state.age, state.gender);
  const tdee = calcTDEE(bmr, state.fitnessLevel);
  const bmi = calcBMI(state.weightKg, state.heightCm);
  const bf = estimateBodyFat(bmi, state.age, state.gender);
  const targetCalories = calcCalorieTarget(tdee, bmr, state.primaryGoal, state.weightKg);
  const macros = calcMacros(targetCalories, state.weightKg, state.primaryGoal, state.dietaryStyle, bf);
  const range = healthyWeightRange(state.heightCm);
  const plan = generateWorkoutPlan(state);
  return { bmr: Math.round(bmr), tdee, bmi, bodyFat: bf, targetCalories, ...macros, healthyRange: range, starterWorkoutPlan: plan };
}

// ─── Persistence ───
export async function saveProgress(step, data) {
  await AsyncStorage.setItem(PROGRESS_KEY, JSON.stringify({ step, data, timestamp: Date.now() }));
}

export async function loadProgress() {
  const raw = await AsyncStorage.getItem(PROGRESS_KEY);
  return raw ? JSON.parse(raw) : null;
}

export async function isOnboardingComplete() {
  return !!(await AsyncStorage.getItem(COMPLETE_KEY));
}

// ─── Complete onboarding ───
export async function completeOnboarding(wizardState) {
  const calc = calculateAll(wizardState);
  const full = { ...wizardState, ...calc, completedAt: new Date().toISOString() };

  try {
    await apiClient.post('/api/user/onboarding', full);
    await apiClient.post('/api/goals', {
      dailyCalorieGoal: calc.targetCalories,
      proteinGoal: calc.protein,
      carbGoal: calc.carbs,
      fatGoal: calc.fat,
      weeklyWorkoutGoal: wizardState.workoutsPerWeek,
      sleepGoal: wizardState.sleepGoalHours,
      waterGoal: calcWaterGoal(wizardState.weightKg),
    });
  } catch {
    // API may not be ready — continue offline
  }

  await AsyncStorage.setItem(COMPLETE_KEY, JSON.stringify(full));
  await AsyncStorage.setItem(PLAN_KEY, JSON.stringify(calc.starterWorkoutPlan));
  await AsyncStorage.removeItem(PROGRESS_KEY);

  // Schedule notifications
  const notif = wizardState.notifications ?? {};
  try {
    await cancelAll();

    if (notif.dailyReminder || notif.weeklyReport || notif.streakAlerts) {
      const granted = await requestPermissions();

      if (granted) {
        if (notif.dailyReminder && notif.reminderTime) {
          const [rh, rm] = notif.reminderTime.split(':').map(Number);
          await scheduleDailyReminder(rh, rm);
        }
        if (notif.weeklyReport) await scheduleWeeklySummary();
        if (notif.streakAlerts) await scheduleStreakAlert();
      }
    }
  } catch {
    // Notification setup is optional and should not block onboarding completion.
  }

  return full;
}
