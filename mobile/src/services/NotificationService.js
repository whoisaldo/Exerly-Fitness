import * as Notifications from 'expo-notifications';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';

const HISTORY_KEY = 'exerly_notification_history';

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: false,
  }),
});

/**
 * Request notification permissions.
 * @returns {Promise<boolean>}
 */
export async function requestPermissions() {
  if (Platform.OS === 'android') {
    await Notifications.setNotificationChannelAsync('default', {
      name: 'default',
      importance: Notifications.AndroidImportance.DEFAULT,
    });
  }
  const { status: existing } = await Notifications.getPermissionsAsync();
  if (existing === 'granted') return true;
  const { status } = await Notifications.requestPermissionsAsync();
  return status === 'granted';
}

/**
 * Schedule a daily local reminder.
 * @param {number} hour
 * @param {number} minute
 */
export async function scheduleDailyReminder(hour, minute) {
  await Notifications.scheduleNotificationAsync({
    content: {
      title: "Time to log your activity!",
      body: "Don't break your streak — log today's workout.",
    },
    trigger: {
      type: 'daily',
      hour,
      minute,
    },
  });
}

/**
 * Schedule weekly summary for Sunday 8pm.
 */
export async function scheduleWeeklySummary() {
  await Notifications.scheduleNotificationAsync({
    content: {
      title: 'Your Weekly Summary',
      body: 'See how you did this week on Exerly!',
    },
    trigger: {
      type: 'weekly',
      weekday: 1,
      hour: 20,
      minute: 0,
    },
  });
}

/**
 * Schedule streak-at-risk alert at 7pm daily.
 */
export async function scheduleStreakAlert() {
  await Notifications.scheduleNotificationAsync({
    content: {
      title: 'Streak at risk!',
      body: "You haven't logged anything today. Don't lose your streak!",
    },
    trigger: {
      type: 'daily',
      hour: 19,
      minute: 0,
    },
  });
}

/**
 * Cancel all scheduled notifications.
 */
export async function cancelAll() {
  await Notifications.cancelAllScheduledNotificationsAsync();
}

/**
 * Log a notification to local history.
 * @param {'achievement'|'challenge'|'friend'|'reminder'|'summary'} type
 * @param {string} message
 */
export async function logNotification(type, message) {
  const raw = await AsyncStorage.getItem(HISTORY_KEY);
  const history = raw ? JSON.parse(raw) : [];
  history.unshift({ type, message, read: false, timestamp: new Date().toISOString() });
  await AsyncStorage.setItem(HISTORY_KEY, JSON.stringify(history.slice(0, 100)));
}

/**
 * Get notification history.
 * @returns {Promise<Array>}
 */
export async function getNotificationHistory() {
  const raw = await AsyncStorage.getItem(HISTORY_KEY);
  return raw ? JSON.parse(raw) : [];
}

/**
 * Mark all notifications as read.
 */
export async function markAllRead() {
  const raw = await AsyncStorage.getItem(HISTORY_KEY);
  if (!raw) return;
  const history = JSON.parse(raw).map((n) => ({ ...n, read: true }));
  await AsyncStorage.setItem(HISTORY_KEY, JSON.stringify(history));
}
