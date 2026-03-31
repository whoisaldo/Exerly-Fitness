/**
 * MET (Metabolic Equivalent of Task) values for common activities.
 * Used to estimate calories burned: calories = MET × weightKg × (duration / 60)
 */
const MET_VALUES = {
  running: 9.8,
  walking: 3.5,
  cycling: 7.5,
  swimming: 8.0,
  weights: 6.0,
  yoga: 3.0,
  hiit: 10.0,
  basketball: 8.0,
  soccer: 8.0,
  tennis: 7.0,
  rowing: 7.0,
  'jump rope': 11.0,
  hiking: 6.0,
  pilates: 3.5,
  dancing: 5.5,
  boxing: 9.0,
  climbing: 8.0,
  stretching: 2.5,
  elliptical: 5.0,
  stairmaster: 9.0,
};

/**
 * Estimate calories burned for a given activity.
 * @param {string} activity - Activity name (case-insensitive)
 * @param {number} durationMinutes - Duration in minutes
 * @param {number} [weightKg=70] - Body weight in kg
 * @returns {number} Estimated calories burned (rounded)
 */
export function estimateCalories(activity, durationMinutes, weightKg = 70) {
  const key = activity?.toLowerCase?.() ?? '';
  const met = MET_VALUES[key] ?? 5.0;
  return Math.round(met * weightKg * (durationMinutes / 60));
}

/** List of common activity names for autocomplete. */
export const COMMON_ACTIVITIES = Object.keys(MET_VALUES).map(
  (k) => k.charAt(0).toUpperCase() + k.slice(1),
);

export default { estimateCalories, COMMON_ACTIVITIES, MET_VALUES };
