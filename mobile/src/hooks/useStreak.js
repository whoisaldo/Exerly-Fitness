import { useMemo } from 'react';
import {
  calculateStreak,
  getLongestStreak,
  getNextMilestone,
  isStreakAtRisk,
} from '../services/StreakService';

/**
 * Hook for streak data.
 * @param {(Date|string)[]} logDates
 * @returns {{ currentStreak: number, longestStreak: number, nextMilestone: number, isAtRisk: boolean }}
 */
export default function useStreak(logDates = []) {
  return useMemo(() => {
    const current = calculateStreak(logDates);
    return {
      currentStreak: current,
      longestStreak: getLongestStreak(logDates),
      nextMilestone: getNextMilestone(current),
      isAtRisk: isStreakAtRisk(logDates),
    };
  }, [logDates]);
}
