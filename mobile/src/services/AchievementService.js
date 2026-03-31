import AsyncStorage from '@react-native-async-storage/async-storage';

const STORAGE_KEY = 'exerly_achievements';

/** All 20 achievements in the system. */
export const achievements = [
  { id: 'first_step', title: 'First Step', desc: 'Log your first activity', icon: 'flash', category: 'activity', targetValue: 1, conditionKey: 'totalActivities' },
  { id: 'streak_7', title: '7 Day Streak', desc: 'Log activity 7 days straight', icon: 'flame', category: 'streak', targetValue: 7, conditionKey: 'currentStreak' },
  { id: 'streak_30', title: '30 Day Warrior', desc: '30 day streak', icon: 'star', category: 'streak', targetValue: 30, conditionKey: 'currentStreak' },
  { id: 'century', title: 'Century Club', desc: '100 total activities logged', icon: 'ribbon', category: 'activity', targetValue: 100, conditionKey: 'totalActivities' },
  { id: 'iron_will', title: 'Iron Will', desc: 'Log 50 workouts', icon: 'barbell', category: 'activity', targetValue: 50, conditionKey: 'totalWorkouts' },
  { id: 'macro_master', title: 'Macro Master', desc: 'Hit all macros 5 days in a row', icon: 'nutrition', category: 'nutrition', targetValue: 5, conditionKey: 'macroDaysStreak' },
  { id: 'sleep_champ', title: 'Sleep Champion', desc: '8+ hours 7 nights in a row', icon: 'moon', category: 'sleep', targetValue: 7, conditionKey: 'sleepStreak' },
  { id: 'goal_crusher', title: 'Goal Crusher', desc: 'Complete all goals in one week', icon: 'trophy', category: 'goals', targetValue: 1, conditionKey: 'weekGoalsComplete' },
  { id: 'perfect_day', title: 'Perfect Day', desc: 'Hit calories, protein, sleep, activity same day', icon: 'checkmark-done', category: 'general', targetValue: 1, conditionKey: 'perfectDays' },
  { id: 'speed_demon', title: 'Speed Demon', desc: 'Log a run activity', icon: 'walk', category: 'activity', targetValue: 1, conditionKey: 'runActivities' },
  { id: 'zen_mode', title: 'Zen Mode', desc: 'Log yoga 3 times', icon: 'body', category: 'activity', targetValue: 3, conditionKey: 'yogaActivities' },
  { id: 'hydrated', title: 'Hydrated', desc: 'Log water goal 7 days straight', icon: 'water', category: 'health', targetValue: 7, conditionKey: 'waterStreak' },
  { id: 'progress_photo', title: 'Progress Poster', desc: 'Add first progress photo', icon: 'camera', category: 'general', targetValue: 1, conditionKey: 'progressPhotos' },
  { id: 'social_butterfly', title: 'Social Butterfly', desc: 'Add first friend', icon: 'people', category: 'social', targetValue: 1, conditionKey: 'friendCount' },
  { id: 'challenger', title: 'Challenger', desc: 'Complete first challenge', icon: 'flag', category: 'social', targetValue: 1, conditionKey: 'challengesCompleted' },
  { id: 'clean_eater', title: 'Clean Eater', desc: 'Log food under calorie goal 7 days', icon: 'leaf', category: 'nutrition', targetValue: 7, conditionKey: 'cleanEatDays' },
  { id: 'heavy_lifter', title: 'Heavy Lifter', desc: 'Log weights activity 10 times', icon: 'barbell', category: 'activity', targetValue: 10, conditionKey: 'weightActivities' },
  { id: 'early_bird', title: 'Early Bird', desc: 'Log activity before 8am', icon: 'sunny', category: 'activity', targetValue: 1, conditionKey: 'earlyActivities' },
  { id: 'night_owl', title: 'Night Owl', desc: 'Log sleep before midnight 5 times', icon: 'cloudy-night', category: 'sleep', targetValue: 5, conditionKey: 'earlyBedtimes' },
  { id: 'legend', title: 'Exerly Legend', desc: 'Unlock 15 other achievements', icon: 'diamond', category: 'general', targetValue: 15, conditionKey: 'unlockedCount' },
];

/**
 * Check all achievements against user data. Returns newly unlocked IDs.
 * @param {Record<string, number>} userData
 * @returns {Promise<string[]>}
 */
export async function checkAchievements(userData = {}) {
  const stored = await getUnlockedIds();
  const newUnlocks = [];

  for (const a of achievements) {
    if (stored.includes(a.id)) continue;
    const val = userData[a.conditionKey] ?? 0;
    if (val >= a.targetValue) {
      newUnlocks.push(a.id);
    }
  }

  if (newUnlocks.length > 0) {
    const all = [...stored, ...newUnlocks];
    await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(all));
  }

  return newUnlocks;
}

/**
 * Get progress for a single achievement.
 * @param {string} id
 * @param {Record<string, number>} userData
 * @returns {{ current: number, target: number, percent: number }}
 */
export function getProgress(id, userData = {}) {
  const a = achievements.find((x) => x.id === id);
  if (!a) return { current: 0, target: 1, percent: 0 };
  const current = Math.min(userData[a.conditionKey] ?? 0, a.targetValue);
  return { current, target: a.targetValue, percent: current / a.targetValue };
}

/**
 * Check if an achievement is unlocked.
 * @param {string} id
 * @returns {Promise<boolean>}
 */
export async function isUnlocked(id) {
  const stored = await getUnlockedIds();
  return stored.includes(id);
}

/** @returns {Promise<string[]>} */
async function getUnlockedIds() {
  const raw = await AsyncStorage.getItem(STORAGE_KEY);
  return raw ? JSON.parse(raw) : [];
}

/** Get all unlocked IDs. */
export async function getAllUnlocked() {
  return getUnlockedIds();
}
