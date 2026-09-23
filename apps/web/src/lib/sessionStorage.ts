import API_CONFIG from '../config';
import { operationID } from './ids';
import { forgetOfflineCopies } from './offlineCache';

export const SESSION_CHANGE_EVENT = 'exerly-session-change';
export const SESSION_KEY = `exerly.session.v2:${API_CONFIG.BASE_URL.replace(/\/+$/, '')}`;
const NOTICE_KEY = `${SESSION_KEY}:signout-notice`;
const GENERATION_KEY = `${SESSION_KEY}:auth-generation`;

export interface StoredSession {
  version: 2;
  scope: string;
  token: string;
  sessionId?: string;
  refreshToken?: string;
  refreshOperation?: string;
  expiresAt: number;
}

export interface SessionResponse {
  token: string;
  sessionId: string;
  refreshToken: string;
  expiresIn: number;
}

export function readSession(): StoredSession | null {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    const session = JSON.parse(raw) as StoredSession;
    if (
      session.version !== 2 ||
      typeof session.scope !== 'string' ||
      !session.scope ||
      typeof session.token !== 'string' ||
      !session.token ||
      !Number.isFinite(session.expiresAt) ||
      (session.refreshOperation !== undefined &&
        (typeof session.refreshOperation !== 'string' ||
          !/^[a-zA-Z0-9._:-]{8,128}$/.test(session.refreshOperation))) ||
      (session.refreshToken &&
        (typeof session.refreshToken !== 'string' ||
          typeof session.refreshOperation !== 'string' ||
          !session.refreshOperation))
    )
      return null;
    return session;
  } catch {
    return null;
  }
}

export function getToken(): string | null {
  return readSession()?.token ?? null;
}

// This identity stays stable during token rotation and changes on every sign-in.
// Async UI work can distinguish a refresh from a different browser account.
export function getSessionScope(): string | null {
  return readSession()?.scope ?? null;
}

export function getAuthGeneration(): string | null {
  try {
    return localStorage.getItem(GENERATION_KEY);
  } catch {
    return null;
  }
}

function writeSession(session: StoredSession): void {
  const previousScope = getSessionScope();
  try {
    if (getSessionScope() !== session.scope) localStorage.setItem(GENERATION_KEY, operationID());
    localStorage.setItem(SESSION_KEY, JSON.stringify(session));
    if (localStorage.getItem(SESSION_KEY) !== JSON.stringify(session))
      throw new Error('Session write was not retained');
    localStorage.removeItem(NOTICE_KEY);
  } catch {
    throw new Error(
      'This browser could not save your session. Allow site storage or free some space, then try again.'
    );
  }
  if (previousScope && previousScope !== session.scope) void forgetOfflineCopies(previousScope);
  window.dispatchEvent(new Event(SESSION_CHANGE_EVENT));
}

export function setToken(token: string): void {
  writeSession({
    version: 2,
    scope: operationID(),
    token,
    refreshOperation: operationID(),
    expiresAt: 0,
  });
}

export function prepareSessionRefresh(expected: StoredSession): StoredSession {
  const current = readSession();
  if (!current || current.scope !== expected.scope)
    throw new Error('The signed-in account changed.');
  if (current.refreshOperation) return current;
  // Old envelopes did not save an upgrade operation. Derive it from their
  // existing sign-in identity so simultaneous tabs select the same operation.
  const refreshOperation = `upgrade:${current.scope}`;
  if (!/^[a-zA-Z0-9._:-]{8,128}$/.test(refreshOperation))
    throw new Error('The saved session could not be read. Sign in again to continue.');
  const prepared = { ...current, refreshOperation };
  writeSession(prepared);
  return prepared;
}

export function saveSession(response: Partial<SessionResponse>, expected?: StoredSession): boolean {
  if (
    typeof response.token !== 'string' ||
    !response.token ||
    typeof response.sessionId !== 'string' ||
    !response.sessionId ||
    typeof response.refreshToken !== 'string' ||
    !response.refreshToken ||
    typeof response.expiresIn !== 'number' ||
    !Number.isFinite(response.expiresIn) ||
    response.expiresIn <= 0
  )
    throw new Error('The sign-in response was incomplete. Please try again.');
  if (expected) {
    const current = readSession();
    if (
      current?.scope !== expected.scope ||
      current.token !== expected.token ||
      current.refreshToken !== expected.refreshToken
    )
      return false;
  }
  // Persist the next operation together with its refresh credential before any
  // request can use it. Tabs and reloads therefore replay the identical pair.
  writeSession({
    version: 2,
    scope: expected?.scope ?? operationID(),
    token: response.token,
    sessionId: response.sessionId,
    refreshToken: response.refreshToken,
    refreshOperation: operationID(),
    expiresAt: Date.now() + response.expiresIn * 1000,
  });
  return true;
}

export function clearToken(expectedScope?: string): void {
  if (expectedScope && getSessionScope() !== expectedScope) return;
  const previousScope = getSessionScope();
  localStorage.setItem(GENERATION_KEY, operationID());
  localStorage.removeItem(SESSION_KEY);
  if (previousScope) void forgetOfflineCopies(previousScope);
  window.dispatchEvent(new Event(SESSION_CHANGE_EVENT));
}

export function subscribeToSession(listener: () => void): () => void {
  const storage = (event: StorageEvent) => {
    if (event.key === SESSION_KEY || event.key === NOTICE_KEY || event.key === null) listener();
  };
  window.addEventListener('storage', storage);
  window.addEventListener(SESSION_CHANGE_EVENT, listener);
  return () => {
    window.removeEventListener('storage', storage);
    window.removeEventListener(SESSION_CHANGE_EVENT, listener);
  };
}

export function getSessionNotice(): string | null {
  try {
    const raw = localStorage.getItem(NOTICE_KEY);
    const notice = JSON.parse(raw || 'null');
    return typeof notice?.message === 'string' && typeof notice?.id === 'string' ? raw : null;
  } catch {
    return null;
  }
}

export function dismissSessionNotice(): void {
  localStorage.removeItem(NOTICE_KEY);
  window.dispatchEvent(new Event(SESSION_CHANGE_EVENT));
}

export function beginSignOutNotice(): string {
  const id = operationID();
  localStorage.setItem(
    NOTICE_KEY,
    JSON.stringify({ id, message: 'Signed out on this browser. Ending the server session…' })
  );
  window.dispatchEvent(new Event(SESSION_CHANGE_EVENT));
  return id;
}

export function finishSignOutNotice(id: string, revoked: boolean): void {
  if (getSessionScope() || JSON.parse(getSessionNotice() || 'null')?.id !== id) return;
  const message = revoked
    ? 'Signed out.'
    : 'Signed out on this browser. We could not reach the server to end its session.';
  localStorage.setItem(NOTICE_KEY, JSON.stringify({ id, message }));
  window.dispatchEvent(new Event(SESSION_CHANGE_EVENT));
}

// Older releases stored an unscoped token for this production API. Never send
// that credential to a different configured API. Keep it intact in that case;
// the person signs in to the other environment separately.
const previousProductionAPI = 'https://exerly-fitness-93dyl.ondigitalocean.app';
if (API_CONFIG.BASE_URL.replace(/\/+$/, '') === previousProductionAPI && !readSession()) {
  try {
    const legacy = localStorage.getItem('token');
    if (legacy) {
      setToken(legacy);
      localStorage.removeItem('token');
    }
  } catch {
    /* Keep the old credential if site storage is unavailable. */
  }
}
