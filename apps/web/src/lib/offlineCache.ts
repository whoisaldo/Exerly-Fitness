import API_CONFIG from '../config';
import { isCalendarDay, todayString } from './dates';

export const OFFLINE_CHANGE = 'exerly-offline-change';
export const RECONNECT = 'exerly-reconnect';
const DATABASE = 'exerly-offline-v1';
const STORE = 'responses';
const environment = API_CONFIG.BASE_URL.replace(/\/+$/, '');
const MAX_BYTES = 2 * 1024 * 1024;
const MAX_ROWS = 64;

interface CachedResponse {
  key: string;
  partition: string;
  version: 1;
  accountID: string;
  path: string;
  body: string;
  savedAt: number;
  requestedAt: number;
}
interface CacheStatus {
  copies: Record<string, number>;
  storageError: boolean;
}
const statuses = new Map<string, CacheStatus>();
let database: Promise<IDBDatabase> | null = null;

function status(scope: string): CacheStatus {
  return statuses.get(scope) ?? { copies: {}, storageError: false };
}
function publish(scope: string, next: CacheStatus): void {
  statuses.set(scope, next);
  window.dispatchEvent(new Event(OFFLINE_CHANGE));
}
export function offlineSnapshot(scope: string | null): string | null {
  return scope ? JSON.stringify(status(scope)) : null;
}
export function subscribeToOffline(listener: () => void): () => void {
  window.addEventListener(OFFLINE_CHANGE, listener);
  return () => window.removeEventListener(OFFLINE_CHANGE, listener);
}
export function subscribeToReconnect(listener: () => void): () => void {
  let resumed = 0;
  const foreground = () => {
    if (!document.hidden && Date.now() - resumed > 1000) {
      resumed = Date.now();
      listener();
    }
  };
  window.addEventListener('online', listener);
  window.addEventListener(RECONNECT, listener);
  window.addEventListener('focus', foreground);
  document.addEventListener('visibilitychange', foreground);
  return () => {
    window.removeEventListener('online', listener);
    window.removeEventListener(RECONNECT, listener);
    window.removeEventListener('focus', foreground);
    document.removeEventListener('visibilitychange', foreground);
  };
}
export function clearInactiveCopies(scope: string): void {
  const previous = status(scope);
  const bootstrap = previous.copies['/api/bootstrap'];
  publish(scope, { ...previous, copies: bootstrap ? { '/api/bootstrap': bootstrap } : {} });
}
function storageFailed(scope: string): void {
  publish(scope, { ...status(scope), storageError: true });
}
function partition(scope: string): string {
  return `${environment}\n${scope}`;
}

function open(): Promise<IDBDatabase> {
  if (database) return database;
  const opening = new Promise<IDBDatabase>((resolve, reject) => {
    const request = indexedDB.open(DATABASE, 1);
    let settled = false;
    const fail = (error: unknown) => {
      settled = true;
      window.clearTimeout(timer);
      reject(error);
    };
    const timer = window.setTimeout(() => fail(new Error('Offline storage is unavailable')), 2500);
    request.onupgradeneeded = () => {
      const store = request.result.createObjectStore(STORE, { keyPath: 'key' });
      store.createIndex('partition', 'partition');
    };
    request.onsuccess = () => {
      window.clearTimeout(timer);
      const db = request.result;
      if (settled) {
        db.close();
        return;
      }
      settled = true;
      db.onversionchange = () => {
        db.close();
        if (database === opening) database = null;
      };
      resolve(db);
    };
    request.onerror = () => {
      fail(request.error);
    };
    request.onblocked = () => {
      fail(new Error('Offline storage is busy'));
    };
  }).catch((error) => {
    if (database === opening) database = null;
    throw error;
  });
  database = opening;
  return opening;
}

async function get(scope: string, path: string): Promise<CachedResponse | null> {
  const db = await open();
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(STORE, 'readonly');
    const request = transaction.objectStore(STORE).get(`${partition(scope)}\n${path}`);
    request.onsuccess = () => {
      const row = request.result as CachedResponse | undefined;
      resolve(
        row?.version === 1 &&
          row.partition === partition(scope) &&
          row.path === path &&
          typeof row.body === 'string' &&
          typeof row.accountID === 'string' &&
          !!row.accountID &&
          Number.isFinite(new Date(row.savedAt).getTime()) &&
          Number.isFinite(row.requestedAt)
          ? row
          : null
      );
    };
    request.onerror = () => reject(request.error);
    transaction.onabort = () => reject(transaction.error);
  });
}

async function put(row: CachedResponse, current: () => boolean): Promise<void> {
  if (row.body.length * 2 > MAX_BYTES / 2) return;
  const db = await open();
  if (!current()) return;
  await new Promise<void>((resolve, reject) => {
    const transaction = db.transaction(STORE, 'readwrite');
    const store = transaction.objectStore(STORE);
    const request = store.index('partition').getAll(row.partition);
    request.onsuccess = () => {
      if (!current()) return;
      const all = request.result as CachedResponse[];
      if (all.some((old) => old.key === row.key && old.requestedAt > row.requestedAt)) return;
      const retained = all
        .filter((old) => old.key !== row.key)
        .sort((a, b) => a.savedAt - b.savedAt);
      let bytes = retained.reduce((sum, old) => sum + old.body.length * 2, row.body.length * 2);
      while (retained.length >= MAX_ROWS || bytes > MAX_BYTES) {
        const index = retained.findIndex((old) => old.path !== '/api/bootstrap');
        if (index < 0) break;
        const [old] = retained.splice(index, 1);
        store.delete(old.key);
        bytes -= old.body.length * 2;
      }
      store.put(row);
    };
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error);
    transaction.onabort = () => reject(transaction.error);
  });
}

function record(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === 'object' && !Array.isArray(value);
}
function numbers(value: unknown, keys: string[], nullable = false): boolean {
  return (
    record(value) &&
    keys.every(
      (key) =>
        (nullable && value[key] === null) ||
        (typeof value[key] === 'number' && Number.isFinite(value[key]))
    )
  );
}
function rows(value: unknown): boolean {
  return Array.isArray(value) && value.every(record);
}
export function validBootstrap(value: unknown): boolean {
  if (
    !record(value) ||
    value.contract_version !== 1 ||
    !record(value.account) ||
    !record(value.onboarding)
  )
    return false;
  const account = value.account;
  const onboarding = value.onboarding;
  return (
    typeof account._id === 'string' &&
    !!account._id &&
    typeof account.email === 'string' &&
    !!account.email &&
    typeof account.timezone === 'string' &&
    ['metric', 'imperial'].includes(String(account.unitSystem)) &&
    typeof onboarding.complete === 'boolean' &&
    record(onboarding.user) &&
    onboarding.user._id === account._id &&
    value.account_id === account._id
  );
}
function allowed(path: string): boolean {
  return new Set([
    '/api/bootstrap',
    '/api/summary',
    '/api/dashboard-data',
    '/api/recent',
    '/api/weight/day',
    '/api/weight/trend',
    '/api/measurements',
    '/api/program',
    '/api/program/checkins',
    '/api/library/foods',
  ]).has(path);
}
function validPayload(path: string, payload: unknown): boolean {
  if (path === '/api/bootstrap') return validBootstrap(payload);
  if (path === '/api/summary')
    return (
      record(payload) &&
      typeof payload.date === 'string' &&
      isCalendarDay(payload.date) &&
      numbers(payload.consumed, ['calories', 'protein', 'carbs', 'fat']) &&
      numbers(payload.targets, ['calories', 'protein_g', 'carbs_g', 'fat_g'], true) &&
      numbers(payload.remaining, ['calories', 'protein_g', 'carbs_g', 'fat_g'], true) &&
      rows(payload.activities) &&
      numbers(payload.water, ['ml', 'revision']) &&
      record(payload.diary_day) &&
      record(payload.meals) &&
      Object.values(payload.meals).every(
        (meal) => record(meal) && rows(meal.entries) && record(meal.totals)
      )
    );
  if (
    ['/api/recent', '/api/library/foods', '/api/program/checkins', '/api/dashboard-data'].includes(
      path
    )
  )
    return rows(payload);
  if (!record(payload)) return false;
  if (path === '/api/weight/day')
    return (
      typeof payload.entry_date === 'string' &&
      isCalendarDay(payload.entry_date) &&
      numbers(payload, ['revision']) &&
      numbers(payload, ['weight_kg'], true)
    );
  if (path === '/api/weight/trend')
    return (
      typeof payload.from === 'string' &&
      isCalendarDay(payload.from) &&
      typeof payload.to === 'string' &&
      isCalendarDay(payload.to) &&
      rows(payload.series) &&
      (payload.summary === null || record(payload.summary))
    );
  if (path === '/api/measurements') return rows(payload.entries) && numbers(payload, ['total']);
  if (path === '/api/program')
    return (
      typeof payload.goal_type === 'string' &&
      record(payload.targets) &&
      record(payload.expenditure)
    );
  return false;
}

async function context(scope: string, url: URL, at = Date.now()) {
  const base = new URL(environment);
  if (
    url.origin !== base.origin ||
    !url.pathname.startsWith(base.pathname.replace(/\/+$/, '') + '/')
  )
    return null;
  const path = url.pathname.slice(base.pathname.replace(/\/+$/, '').length);
  if (!allowed(path)) return null;
  const params = new URLSearchParams(url.search);
  params.delete('t');
  params.sort();
  const original = `${path}${params.size ? '?' + params.toString() : ''}`;
  if (path === '/api/bootstrap') return { key: original, path, owner: null };
  const bootstrap = await get(scope, '/api/bootstrap');
  if (!bootstrap) return null;
  const data = JSON.parse(bootstrap.body);
  if (!validBootstrap(data) || data.account_id !== bootstrap.accountID) return null;
  const explicitDay =
    params.has('entry_date') || params.has('date') || (params.has('from') && params.has('to'));
  const independent = path === '/api/library/foods';
  const day =
    explicitDay || independent ? '' : `\nday=${todayString(data.account.timezone, new Date(at))}`;
  return { key: original + day, path, owner: bootstrap.accountID };
}

/** Called only for display reads explicitly opting in to offline fallback. */
export async function rememberResponse(
  scope: string,
  url: URL,
  response: Response,
  started: number,
  current: () => boolean
): Promise<void> {
  try {
    if (!response.ok || !response.headers.get('content-type')?.includes('application/json')) return;
    const ctx = await context(scope, url, started);
    if (!ctx || !current()) return;
    const body = await response.clone().text();
    const payload = JSON.parse(body);
    if (!validPayload(ctx.path, payload) || !current()) return;
    const owner = ctx.owner ?? payload.account_id;
    await put(
      {
        version: 1,
        key: `${partition(scope)}\n${ctx.key}`,
        partition: partition(scope),
        accountID: owner,
        path: ctx.key,
        body,
        requestedAt: started,
        savedAt: Date.now(),
      },
      current
    );
    if (!current()) return;
    const copies = { ...status(scope).copies };
    delete copies[ctx.key];
    publish(scope, { copies, storageError: false });
  } catch {
    if (current()) storageFailed(scope);
  }
}

export async function cachedResponse(
  scope: string,
  url: URL,
  current: () => boolean
): Promise<Response | null> {
  try {
    const ctx = await context(scope, url);
    if (!ctx || !current()) return null;
    const row = await get(scope, ctx.key);
    if (!row || (ctx.owner && row.accountID !== ctx.owner) || !current()) return null;
    const payload = JSON.parse(row.body);
    if (
      !validPayload(ctx.path, payload) ||
      (ctx.path === '/api/bootstrap' && payload.account_id !== row.accountID)
    )
      return null;
    publish(scope, {
      ...status(scope),
      copies: { ...status(scope).copies, [ctx.key]: row.savedAt },
    });
    return new Response(row.body, {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'X-Exerly-Offline-Saved-At': String(row.savedAt),
      },
    });
  } catch {
    if (current()) storageFailed(scope);
    return null;
  }
}

// Profile and setup acknowledgements can arrive after a bootstrap request began.
// Preserve those accepted changes in the saved account before the next reload.
async function rememberAccount(
  scope: string,
  account: unknown,
  setup: unknown,
  current: () => boolean
): Promise<void> {
  const started = Date.now();
  try {
    const row = await get(scope, '/api/bootstrap');
    if (!row || !record(account) || row.accountID !== account._id || !current()) return;
    const saved = JSON.parse(row.body);
    if (!validBootstrap(saved)) return;
    if ((saved.account.preferencesRevision ?? 0) > (account.preferencesRevision ?? 0)) return;
    const next = {
      ...saved,
      account,
      onboarding: setup ?? { ...saved.onboarding, user: account },
      ...(record(setup) ? { targets: setup.targets } : {}),
    };
    await rememberResponse(
      scope,
      new URL(`${environment}/api/bootstrap`),
      new Response(JSON.stringify(next), { headers: { 'Content-Type': 'application/json' } }),
      started,
      current
    );
  } catch {
    if (current()) storageFailed(scope);
  }
}

export async function rememberAccountResponse(
  scope: string,
  url: URL,
  response: Response,
  current: () => boolean
): Promise<void> {
  const base = new URL(environment);
  const path = url.pathname.slice(base.pathname.replace(/\/+$/, '').length);
  const setup = path === '/api/onboarding/complete' || path === '/api/onboarding/status';
  if (!setup && path !== '/api/preferences') return;
  // These are authoritative responses. Await storage before the caller shows
  // completion, so an immediate reload keeps the accepted setup and calendar.
  let payload;
  try {
    payload = await response.clone().json();
  } catch {
    return;
  }
  if (record(payload) && record(payload.user) && (!setup || typeof payload.complete === 'boolean'))
    await rememberAccount(scope, payload.user, setup ? payload : null, current);
}

export async function forgetOfflineCopies(scope: string): Promise<void> {
  statuses.delete(scope);
  window.dispatchEvent(new Event(OFFLINE_CHANGE));
  try {
    const db = await open();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE, 'readwrite');
      const request = tx.objectStore(STORE).index('partition').openKeyCursor(partition(scope));
      request.onsuccess = () => {
        const cursor = request.result;
        if (cursor) {
          tx.objectStore(STORE).delete(cursor.primaryKey);
          cursor.continue();
        }
      };
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
      tx.onabort = () => reject(tx.error);
    });
  } catch {
    /* An inaccessible cache cannot be used without its original sign-in scope. */
  }
}
