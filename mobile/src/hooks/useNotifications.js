import { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import { AppState } from 'react-native';
import {
  requestPermissions,
  scheduleDailyReminder,
  getNotificationHistory,
  markAllRead,
} from '../services/NotificationService';

/**
 * Hook for notifications.
 */
export default function useNotifications() {
  const [notifications, setNotifications] = useState([]);
  const mounted = useRef(true);

  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; };
  }, []);

  const refresh = useCallback(async () => {
    const history = await getNotificationHistory();
    if (mounted.current) setNotifications(history);
  }, []);

  useEffect(() => {
    refresh();
    const sub = AppState.addEventListener('change', (state) => {
      if (state === 'active') refresh();
    });
    return () => sub.remove();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const unreadCount = notifications.filter((n) => !n.read).length;

  const handleMarkAllRead = useCallback(async () => {
    await markAllRead();
    await refresh();
  }, [refresh]);

  return useMemo(
    () => ({
      requestPermissions,
      scheduleDailyReminder,
      notifications,
      unreadCount,
      refresh,
      markAllRead: handleMarkAllRead,
    }),
    [notifications, unreadCount, refresh, handleMarkAllRead],
  );
}
