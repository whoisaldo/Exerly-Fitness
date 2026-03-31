import { Platform } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';

const SYNC_KEY = 'exerly_last_health_sync';

/**
 * Initialize platform health integration.
 * Placeholder — requires native modules (react-native-health / Google Fit).
 * @returns {Promise<boolean>}
 */
export async function initHealth() {
  if (Platform.OS === 'ios') {
    // Would call react-native-health initHealthKit
    return true;
  }
  if (Platform.OS === 'android') {
    // Would call @react-native-google-fit auth
    return true;
  }
  return false;
}

/**
 * Sync steps for a given date (placeholder).
 * @param {Date} [date]
 * @returns {Promise<number>}
 */
export async function syncSteps(date = new Date()) {
  // Real implementation would read from HealthKit / Google Fit
  return 0;
}

/**
 * Sync active calories (placeholder).
 * @param {Date} [date]
 * @returns {Promise<number>}
 */
export async function syncCalories(date = new Date()) {
  return 0;
}

/**
 * Run all sync operations for today.
 */
export async function syncAll() {
  await syncSteps();
  await syncCalories();
  await AsyncStorage.setItem(SYNC_KEY, new Date().toISOString());
}

/**
 * Get timestamp of last health sync.
 * @returns {Promise<string|null>}
 */
export async function getLastSyncTime() {
  return AsyncStorage.getItem(SYNC_KEY);
}
