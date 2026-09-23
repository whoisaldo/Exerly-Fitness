import { useEffect, useSyncExternalStore } from 'react';
import { useLocation } from 'react-router-dom';
import { useSessionScope } from '../../hooks/useSession';
import { shellSnapshot, subscribeToShell } from '../../lib/offlineShell';
import {
  clearInactiveCopies,
  offlineSnapshot,
  RECONNECT,
  subscribeToOffline,
} from '../../lib/offlineCache';

export function ConnectionStatus() {
  const scope = useSessionScope();
  const location = useLocation();
  const shell = useSyncExternalStore(subscribeToShell, shellSnapshot, () => null);
  const snapshot = useSyncExternalStore(
    subscribeToOffline,
    () => offlineSnapshot(scope),
    () => null
  );
  useEffect(() => {
    if (scope) clearInactiveCopies(scope);
  }, [scope, location.pathname, location.search]);
  if (!scope || !snapshot) return null;
  const state = JSON.parse(snapshot) as { copies: Record<string, number>; storageError: boolean };
  const times = Object.values(state.copies);
  if (!times.length && !state.storageError && shell !== 'unavailable' && shell !== 'update')
    return null;
  const savedAt = times.length ? new Date(Math.min(...times)) : null;
  return (
    <section
      aria-label="Connection status"
      className="border-b border-primary/30 bg-surface-1 px-4 py-3 text-slate-200"
    >
      <div className="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-3">
        <p role="status" className="text-pretty text-sm">
          {savedAt ? (
            <>
              Offline copy. Showing saved data from{' '}
              <time dateTime={savedAt.toISOString()}>{savedAt.toLocaleString()}</time>. Reconnect to
              refresh. Pending changes keep their own save status.
            </>
          ) : state.storageError ? (
            'Offline copies are unavailable in this browser. Your synced data remains online and existing drafts are preserved.'
          ) : shell === 'update' ? (
            'An app update is ready. Finish your work, then close all Exerly tabs and reopen to use it.'
          ) : (
            'This browser could not save the app for offline startup. Keep this tab open while disconnected.'
          )}
        </p>
        {shell === 'update' && (savedAt || state.storageError) && (
          <p className="text-pretty text-sm">
            An app update is ready. Finish your work, then close all Exerly tabs and reopen to use
            it.
          </p>
        )}
        <button
          type="button"
          onClick={() => window.dispatchEvent(new Event(RECONNECT))}
          className="min-h-11 rounded-lg border border-white/20 px-4 text-sm text-slate-100"
        >
          Refresh saved data
        </button>
      </div>
    </section>
  );
}
