import AsyncStorage from '@react-native-async-storage/async-storage';
import apiClient from '../api/client';

const KEYS = {
  CUSTOM: 'food_library_custom',
  FAVORITES: 'food_library_favorites',
  RECENTS: 'food_library_recents',
  LOG: 'food_library_log',
  SYNC_QUEUE: 'food_library_sync_queue',
};

const MAX_FAVORITES = 100;
const MAX_RECENTS = 30;

let syncQueue = [];

function generateId() {
  return `${Date.now()}_${Math.random().toString(36).slice(2, 9)}`;
}

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

// ---------- Nutrition calculation ----------

export function calculateNutrition(food, grams) {
  const ratio = grams / 100;
  return {
    calories: Math.round((food.calories ?? 0) * ratio),
    protein: Math.round(((food.protein ?? 0) * ratio) * 10) / 10,
    carbs: Math.round(((food.carbs ?? 0) * ratio) * 10) / 10,
    fat: Math.round(((food.fat ?? 0) * ratio) * 10) / 10,
    sugar: Math.round(((food.sugar ?? 0) * ratio) * 10) / 10,
    fiber: Math.round(((food.fiber ?? 0) * ratio) * 10) / 10,
    sodium: Math.round((food.sodium ?? 0) * ratio),
  };
}

// ---------- Custom Foods ----------

export async function getCustomFoods() {
  try {
    const raw = await AsyncStorage.getItem(KEYS.CUSTOM);
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

export async function saveCustomFood(food) {
  const foods = await getCustomFoods();
  const newFood = {
    ...food,
    id: `custom_${generateId()}`,
    source: 'custom',
  };
  foods.unshift(newFood);
  await AsyncStorage.setItem(KEYS.CUSTOM, JSON.stringify(foods));
  return newFood;
}

export async function updateCustomFood(id, updates) {
  const foods = await getCustomFoods();
  const idx = foods.findIndex((f) => f.id === id);
  if (idx >= 0) {
    foods[idx] = { ...foods[idx], ...updates };
    await AsyncStorage.setItem(KEYS.CUSTOM, JSON.stringify(foods));
  }
}

export async function deleteCustomFood(id) {
  const foods = await getCustomFoods();
  const filtered = foods.filter((f) => f.id !== id);
  await AsyncStorage.setItem(KEYS.CUSTOM, JSON.stringify(filtered));
}

// ---------- Favorites ----------

export async function getFavorites() {
  try {
    const raw = await AsyncStorage.getItem(KEYS.FAVORITES);
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

export async function addFavorite(food) {
  const favs = await getFavorites();
  if (favs.some((f) => f.id === food.id)) return;
  favs.unshift(food);
  if (favs.length > MAX_FAVORITES) favs.pop();
  await AsyncStorage.setItem(KEYS.FAVORITES, JSON.stringify(favs));
}

export async function removeFavorite(id) {
  const favs = await getFavorites();
  const filtered = favs.filter((f) => f.id !== id);
  await AsyncStorage.setItem(KEYS.FAVORITES, JSON.stringify(filtered));
}

export async function isFavorite(id) {
  const favs = await getFavorites();
  return favs.some((f) => f.id === id);
}

// ---------- Recents ----------

export async function getRecents() {
  try {
    const raw = await AsyncStorage.getItem(KEYS.RECENTS);
    return raw ? JSON.parse(raw).slice(0, MAX_RECENTS) : [];
  } catch {
    return [];
  }
}

export async function addToRecents(food) {
  const recents = await getRecents();
  const filtered = recents.filter((f) => f.id !== food.id);
  filtered.unshift(food);
  if (filtered.length > MAX_RECENTS) filtered.length = MAX_RECENTS;
  await AsyncStorage.setItem(KEYS.RECENTS, JSON.stringify(filtered));
}

// ---------- Food Log ----------

async function getLogStore() {
  try {
    const raw = await AsyncStorage.getItem(KEYS.LOG);
    return raw ? JSON.parse(raw) : {};
  } catch {
    return {};
  }
}

async function saveLogStore(store) {
  await AsyncStorage.setItem(KEYS.LOG, JSON.stringify(store));
}

export async function getTodayLog() {
  const store = await getLogStore();
  return store[todayKey()] ?? [];
}

export async function addFoodEntry(food, serving) {
  const grams = serving.grams ?? food.servingGrams ?? 100;
  const nutrition = calculateNutrition(food, grams);

  const entry = {
    id: generateId(),
    food,
    grams,
    servings: serving.servings ?? 1,
    mealType: serving.mealType ?? 'snack',
    loggedAt: new Date().toISOString(),
    ...nutrition,
  };

  const store = await getLogStore();
  const key = todayKey();
  if (!store[key]) store[key] = [];
  store[key].push(entry);
  await saveLogStore(store);
  await addToRecents(food);
  queueSync(entry);
  return entry;
}

export async function removeFoodEntry(entryId) {
  const store = await getLogStore();
  const key = todayKey();
  if (store[key]) {
    store[key] = store[key].filter((e) => e.id !== entryId);
    await saveLogStore(store);
  }
}

export async function updateFoodEntry(entryId, serving) {
  const store = await getLogStore();
  const key = todayKey();
  if (!store[key]) return;

  const idx = store[key].findIndex((e) => e.id === entryId);
  if (idx < 0) return;

  const entry = store[key][idx];
  const grams = serving.grams ?? entry.grams;
  const nutrition = calculateNutrition(entry.food, grams);

  store[key][idx] = {
    ...entry,
    grams,
    servings: serving.servings ?? entry.servings,
    mealType: serving.mealType ?? entry.mealType,
    ...nutrition,
  };

  await saveLogStore(store);
}

export async function getDailyTotals() {
  const entries = await getTodayLog();
  return entries.reduce(
    (acc, e) => ({
      calories: acc.calories + (e.calories ?? 0),
      protein: acc.protein + (e.protein ?? 0),
      carbs: acc.carbs + (e.carbs ?? 0),
      fat: acc.fat + (e.fat ?? 0),
      sugar: acc.sugar + (e.sugar ?? 0),
      fiber: acc.fiber + (e.fiber ?? 0),
    }),
    { calories: 0, protein: 0, carbs: 0, fat: 0, sugar: 0, fiber: 0 },
  );
}

// ---------- Sync ----------

function queueSync(entry) {
  syncQueue.push(entry);
  processSyncQueue();
}

async function processSyncQueue() {
  if (syncQueue.length === 0) return;
  const batch = [...syncQueue];
  syncQueue = [];

  try {
    for (const entry of batch) {
      await apiClient.post('/api/food', {
        name: entry.food.name,
        calories: entry.calories,
        protein: entry.protein,
        carbs: entry.carbs,
        fat: entry.fat,
        sugar: entry.sugar,
        mealType: entry.mealType,
      });
    }
  } catch {
    syncQueue.push(...batch);
    try {
      await AsyncStorage.setItem(
        KEYS.SYNC_QUEUE,
        JSON.stringify(syncQueue),
      );
    } catch {}
  }
}

export async function retrySyncQueue() {
  try {
    const raw = await AsyncStorage.getItem(KEYS.SYNC_QUEUE);
    if (raw) {
      const queued = JSON.parse(raw);
      syncQueue.push(...queued);
      await AsyncStorage.removeItem(KEYS.SYNC_QUEUE);
      processSyncQueue();
    }
  } catch {}
}
