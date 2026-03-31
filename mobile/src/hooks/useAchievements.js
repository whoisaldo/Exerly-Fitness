import { useState, useEffect, useCallback, useMemo } from 'react';
import {
  achievements,
  checkAchievements as check,
  getAllUnlocked,
  getProgress,
} from '../services/AchievementService';

/**
 * Hook wrapping AchievementService.
 */
export default function useAchievements() {
  const [unlocked, setUnlocked] = useState([]);
  const [newUnlocks, setNewUnlocks] = useState([]);

  useEffect(() => {
    getAllUnlocked().then(setUnlocked);
  }, []);

  const checkAll = useCallback(async (userData) => {
    const fresh = await check(userData);
    if (fresh.length > 0) {
      setNewUnlocks(fresh);
      const all = await getAllUnlocked();
      setUnlocked(all);
    }
    return fresh;
  }, []);

  return useMemo(
    () => ({
      achievements,
      unlocked,
      newUnlocks,
      checkAchievements: checkAll,
      getProgress,
    }),
    [unlocked, newUnlocks, checkAll],
  );
}
