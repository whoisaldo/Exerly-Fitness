type ShellState = 'unavailable' | 'ready' | 'update' | null;
let state: ShellState = null;
const listeners = new Set<() => void>();
export const shellSnapshot = () => state;
export function subscribeToShell(listener: () => void): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}
function publish(next: ShellState) {
  state = next;
  for (const listener of listeners) listener();
}

export function registerOfflineShell(): void {
  if (!import.meta.env.PROD) return;
  if (!window.isSecureContext || !('serviceWorker' in navigator)) {
    publish('unavailable');
    return;
  }
  void navigator.serviceWorker
    .register('/offline-worker.js', { updateViaCache: 'none' })
    .then((registration) => {
      const installed = () => {
        if (registration.waiting && navigator.serviceWorker.controller) publish('update');
        else if (registration.active) publish('ready');
      };
      installed();
      registration.addEventListener('updatefound', () => {
        const worker = registration.installing;
        worker?.addEventListener('statechange', () => {
          if (worker.state === 'installed') installed();
          if (worker.state === 'redundant' && !registration.active) publish('unavailable');
        });
      });
      navigator.serviceWorker.addEventListener('controllerchange', installed);
      // Browser updates normally run on navigation. Also check when an open app
      // returns to the foreground, without interrupting the current form.
      document.addEventListener('visibilitychange', () => {
        if (!document.hidden) void registration.update().catch(() => {});
      });
      window.addEventListener('online', () => {
        void registration.update().catch(() => {});
      });
    })
    .catch(() => {
      publish(navigator.serviceWorker.controller ? 'ready' : 'unavailable');
      window.addEventListener('online', registerOfflineShell, { once: true });
    });
}
