import { useState, useEffect, useCallback, useRef } from 'react';
import { AppState } from 'react-native';
import { syncAll, getLastSyncTime } from '../services/HealthSyncService';

/**
 * Hook for health data synchronization.
 */
export default function useHealthSync() {
  const [syncing, setSyncing] = useState(false);
  const [lastSync, setLastSync] = useState(null);
  const mounted = useRef(true);

  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; };
  }, []);

  const syncNow = useCallback(async () => {
    setSyncing(true);
    try {
      await syncAll();
      const ts = await getLastSyncTime();
      if (mounted.current) setLastSync(ts);
    } finally {
      if (mounted.current) setSyncing(false);
    }
  }, []);

  useEffect(() => {
    getLastSyncTime().then((ts) => { if (mounted.current) setLastSync(ts); });
    const sub = AppState.addEventListener('change', (state) => {
      if (state === 'active') syncNow();
    });
    return () => sub.remove();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  return { syncing, lastSync, syncNow };
}
