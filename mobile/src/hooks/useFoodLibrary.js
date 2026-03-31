import { useState, useEffect, useCallback } from 'react';
import * as FoodLibraryService from '../services/FoodLibraryService';

export default function useFoodLibrary() {
  const [favorites, setFavorites] = useState([]);
  const [recents, setRecents] = useState([]);
  const [customFoods, setCustomFoods] = useState([]);
  const [todayLog, setTodayLog] = useState([]);
  const [dailyTotals, setDailyTotals] = useState({
    calories: 0, protein: 0, carbs: 0, fat: 0, sugar: 0, fiber: 0,
  });

  const refreshAll = useCallback(async () => {
    try {
      const [favs, recs, custom, log, totals] = await Promise.all([
        FoodLibraryService.getFavorites(),
        FoodLibraryService.getRecents(),
        FoodLibraryService.getCustomFoods(),
        FoodLibraryService.getTodayLog(),
        FoodLibraryService.getDailyTotals(),
      ]);
      setFavorites(favs);
      setRecents(recs);
      setCustomFoods(custom);
      setTodayLog(log);
      setDailyTotals(totals);
    } catch {
      setFavorites([]);
      setRecents([]);
      setCustomFoods([]);
      setTodayLog([]);
      setDailyTotals({
        calories: 0, protein: 0, carbs: 0, fat: 0, sugar: 0, fiber: 0,
      });
    }
  }, []);

  useEffect(() => {
    refreshAll();
    FoodLibraryService.retrySyncQueue();
  }, [refreshAll]);

  const toggleFavorite = useCallback(async (food) => {
    const isFav = await FoodLibraryService.isFavorite(food.id);
    if (isFav) {
      await FoodLibraryService.removeFavorite(food.id);
    } else {
      await FoodLibraryService.addFavorite(food);
    }
    setFavorites(await FoodLibraryService.getFavorites());
    return !isFav;
  }, []);

  const logFood = useCallback(async (food, serving) => {
    const entry = await FoodLibraryService.addFoodEntry(food, serving);
    setTodayLog(await FoodLibraryService.getTodayLog());
    setDailyTotals(await FoodLibraryService.getDailyTotals());
    setRecents(await FoodLibraryService.getRecents());
    return entry;
  }, []);

  const removeEntry = useCallback(async (entryId) => {
    await FoodLibraryService.removeFoodEntry(entryId);
    setTodayLog(await FoodLibraryService.getTodayLog());
    setDailyTotals(await FoodLibraryService.getDailyTotals());
  }, []);

  return {
    favorites,
    recents,
    customFoods,
    todayLog,
    dailyTotals,
    toggleFavorite,
    logFood,
    removeEntry,
    refreshAll,
  };
}
