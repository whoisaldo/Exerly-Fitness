import { isSameDay } from '../utils/dateHelpers';

/**
 * Calculate current consecutive-day streak from log dates.
 * @param {(Date|string)[]} logDates - Array of date strings/objects
 * @returns {number}
 */
export function calculateStreak(logDates = []) {
  if (logDates.length === 0) return 0;

  const sorted = [...logDates]
    .map((d) => new Date(d))
    .sort((a, b) => b - a);

  const today = new Date();
  const yesterday = new Date(today);
  yesterday.setDate(yesterday.getDate() - 1);

  if (!isSameDay(sorted[0], today) && !isSameDay(sorted[0], yesterday)) {
    return 0;
  }

  let streak = 1;
  for (let i = 1; i < sorted.length; i++) {
    const prev = new Date(sorted[i - 1]);
    prev.setDate(prev.getDate() - 1);
    if (isSameDay(sorted[i], prev)) {
      streak++;
    } else if (!isSameDay(sorted[i], sorted[i - 1])) {
      break;
    }
  }

  return streak;
}

/**
 * Get longest streak ever achieved.
 * @param {(Date|string)[]} logDates
 * @returns {number}
 */
export function getLongestStreak(logDates = []) {
  if (logDates.length === 0) return 0;

  const days = [...new Set(
    logDates.map((d) => new Date(d).toISOString().slice(0, 10)),
  )].sort();

  let longest = 1;
  let current = 1;

  for (let i = 1; i < days.length; i++) {
    const prev = new Date(days[i - 1]);
    prev.setDate(prev.getDate() + 1);
    if (days[i] === prev.toISOString().slice(0, 10)) {
      current++;
      longest = Math.max(longest, current);
    } else {
      current = 1;
    }
  }

  return longest;
}

/**
 * Returns true if no activity logged today and it's past 6pm.
 * @param {(Date|string)[]} logDates
 * @returns {boolean}
 */
export function isStreakAtRisk(logDates = []) {
  const now = new Date();
  if (now.getHours() < 18) return false;
  return !logDates.some((d) => isSameDay(new Date(d), now));
}

/**
 * Next milestone from [7, 14, 30, 50, 100].
 * @param {number} current
 * @returns {number}
 */
export function getNextMilestone(current) {
  const milestones = [7, 14, 30, 50, 100];
  return milestones.find((m) => m > current) ?? 100;
}
