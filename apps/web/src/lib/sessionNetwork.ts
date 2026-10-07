import API_CONFIG from '../config';
import { ApiError } from './apiError';
import { cachedResponse, rememberResponse, rememberAccountResponse } from './offlineCache';
import {
  clearToken,
  getSessionScope,
  subscribeToSession,
  readSession,
  saveSession,
  prepareSessionRefresh,
  beginSignOutNotice,
  finishSignOutNotice,
  type SessionResponse,
  type StoredSession,
} from './sessionStorage';

let unauthorizedHandler: (() => void) | null = null;
export function setUnauthorizedHandler(handler: () => void): void {
  unauthorizedHandler = handler;
}

function changedSession(): ApiError {
  return new ApiError(409, 'The signed-in account changed. Open this page again before saving.');
}

function currentSession(expected: StoredSession): StoredSession {
  const current = readSession();
  if (!current || current.scope !== expected.scope) throw changedSession();
  return current;
}

async function sessionResponse(session: StoredSession): Promise<{
  status: number;
  ok: boolean;
  payload: (Partial<SessionResponse> & { message?: string }) | null;
}> {
  const controller = new AbortController();
  const timeout = window.setTimeout(() => controller.abort(), 12000);
  try {
    const response = await fetch(
      `${API_CONFIG.BASE_URL}${session.refreshToken ? '/auth/token' : '/auth/refresh'}`,
      {
        method: 'POST',
        signal: controller.signal,
        headers: {
          'Content-Type': 'application/json',
          'X-Session-Protocol': '2',
          'X-Device-Name': 'Exerly web',
          'Idempotency-Key': session.refreshOperation!,
          ...(!session.refreshToken ? { Authorization: `Bearer ${session.token}` } : {}),
        },
        body: JSON.stringify(session.refreshToken ? { refreshToken: session.refreshToken } : {}),
      }
    );
    const payload = await response.json().catch(() => null);
    return { status: response.status, ok: response.ok, payload };
  } catch {
    throw new ApiError(
      0,
      'Could not connect to renew your session. Your saved changes are still here. Retry when you are connected.'
    );
  } finally {
    window.clearTimeout(timeout);
  }
}

const refreshing = new Map<string, Promise<StoredSession>>();
export function refreshSession(expected: StoredSession, force = false): Promise<StoredSession> {
  const current = prepareSessionRefresh(currentSession(expected));
  if (
    current.refreshToken &&
    ((!force && current.expiresAt > Date.now() + 30000) ||
      current.refreshToken !== expected.refreshToken)
  )
    return Promise.resolve(current);
  const pending = refreshing.get(current.scope);
  if (pending) return pending;

  const promise = (async () => {
    const response = await sessionResponse(current);
    // A different tab may have saved the same rotation or a later one while this
    // request was pending. Its credentials win, including after an old 401.
    const latest = currentSession(current);
    if (latest.refreshToken !== current.refreshToken || latest.token !== current.token)
      return latest;
    const payload = response.payload;
    if (!response.ok) {
      if (response.status === 401) {
        clearToken(current.scope);
        unauthorizedHandler?.();
      }
      throw new ApiError(
        response.status,
        payload?.message ||
          'Could not renew your session. Your saved changes are still on this browser.'
      );
    }
    saveSession(payload ?? {}, current);
    return currentSession(current);
  })().finally(() => {
    if (refreshing.get(current.scope) === promise) refreshing.delete(current.scope);
  });
  refreshing.set(current.scope, promise);
  return promise;
}

function tokenSessionID(token: string): string | undefined {
  try {
    const segment = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    return JSON.parse(atob(segment)).sid;
  } catch {
    return undefined;
  }
}

async function networkFetch(input: string | URL, init: RequestInit = {}): Promise<Response> {
  const destination = new URL(input, window.location.href);
  const base = new URL(API_CONFIG.BASE_URL);
  if (
    destination.origin !== base.origin ||
    !destination.pathname.startsWith(`${base.pathname.replace(/\/+$/, '')}/`)
  )
    throw new Error('Authenticated requests must use the configured API.');

  const original = readSession();
  const headers = new Headers(init.headers);
  const supplied = headers.get('Authorization')?.replace(/^Bearer /, '');
  if (!original) {
    if (supplied) throw changedSession();
    return fetch(input, init);
  }
  // Old screen callbacks can still hold a token. Permit a rotation within that
  // same server session, but never send their body as a newly signed-in account.
  if (
    supplied &&
    supplied !== original.token &&
    (!original.sessionId || tokenSessionID(supplied) !== original.sessionId)
  )
    throw changedSession();

  let session = await refreshSession(original);
  const send = () => {
    currentSession(original);
    headers.set('Authorization', `Bearer ${session.token}`);
    return fetch(input, { ...init, headers });
  };
  let response = await send();
  if (response.status !== 401) return response;

  // Authentication runs before route mutations. Only a rejected credential is
  // retried here, once, with the caller's original body and operation identity.
  // Network failures and lost mutation responses remain the durable queue's job.
  session = await refreshSession(session, true);
  response = await send();
  if (response.status === 401) {
    currentSession(original);
    // A route may reject a password confirmation with 401 while the session is
    // still valid. Let that form display the error without signing the user out.
    const validation = await fetch(`${API_CONFIG.BASE_URL}/api/me`, {
      headers: { Authorization: `Bearer ${session.token}` },
      signal: init.signal,
    });
    if (validation.status === 401 && getSessionScope() === original.scope) {
      clearToken(original.scope);
      unauthorizedHandler?.();
      throw new ApiError(401, 'Your session ended. Sign in again.');
    }
  }
  return response;
}

export interface AuthenticatedRequest extends RequestInit {
  // Opt in only for display reads. Conflict review and recovery reads must
  // observe the server before they can acknowledge a pending operation.
  offlineFallback?: boolean;
}

export async function authenticatedFetch(
  input: string | URL,
  options: AuthenticatedRequest = {}
): Promise<Response> {
  const { offlineFallback = false, ...init } = options;
  const scope = getSessionScope();
  const url = new URL(input, window.location.href);
  const started = Date.now();
  const current = () => getSessionScope() === scope;
  const read = (init.method ?? 'GET').toUpperCase() === 'GET';
  const canRead = offlineFallback && !!scope && read;
  const controller = new AbortController();
  const abort = () => controller.abort();
  const stopWatching =
    read && scope
      ? subscribeToSession(() => {
          if (!current()) abort();
        })
      : null;
  if (init.signal?.aborted) controller.abort();
  init.signal?.addEventListener('abort', abort, { once: true });
  const timeout = window.setTimeout(abort, 12000);
  try {
    const response = await networkFetch(input, { ...init, signal: controller.signal });
    if (read && !current()) throw changedSession();
    if (canRead && response.ok) await rememberResponse(scope!, url, response, started, current);
    if (scope && response.ok && current())
      await rememberAccountResponse(scope, url, response, current);
    if (canRead && response.status >= 500 && !init.signal?.aborted) {
      const copy = await cachedResponse(scope!, url, current);
      if (copy) return copy;
    }
    // A late mutation acknowledgement still belongs to the original durable
    // queue. Its caller owns that account's storage key and guards UI updates.
    // Reads can never cross a sign-in boundary.
    if (read && !current()) throw changedSession();
    return response;
  } catch (error) {
    if (!current()) throw changedSession();
    if (init.signal?.aborted) throw error;
    const connectionFailure =
      error instanceof TypeError ||
      (error instanceof ApiError && error.status === 0) ||
      (error instanceof DOMException && error.name === 'AbortError');
    if (canRead && (connectionFailure || (error instanceof ApiError && error.status >= 500))) {
      const copy = await cachedResponse(scope!, url, current);
      if (copy) return copy;
    }
    if (connectionFailure && !(error instanceof ApiError))
      throw new ApiError(
        0,
        'Could not connect. Saved changes remain on this browser. Reconnect and try again.'
      );
    throw error;
  } finally {
    window.clearTimeout(timeout);
    stopWatching?.();
    init.signal?.removeEventListener('abort', abort);
  }
}

// Local sign-out happens immediately. Revocation uses only the captured
// credential and can never restore it over a later sign-in.
export async function signOutSession(): Promise<boolean> {
  const session = readSession();
  clearToken();
  if (!session) return true;
  const notice = beginSignOutNotice();
  const finished = (revoked: boolean) => {
    finishSignOutNotice(notice, revoked);
    return revoked;
  };
  const controller = new AbortController();
  const timeout = window.setTimeout(() => controller.abort(), 12000);
  try {
    let token = session.token;
    let response = await fetch(`${API_CONFIG.BASE_URL}/auth/logout`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: '{}',
      signal: controller.signal,
    });
    if (response.status === 401 && session.refreshToken) {
      const refreshed = await sessionResponse(session);
      if (refreshed.status === 401) return finished(true);
      if (!refreshed.ok || !refreshed.payload?.token) return finished(false);
      token = refreshed.payload.token;
      response = await fetch(`${API_CONFIG.BASE_URL}/auth/logout`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: '{}',
        signal: controller.signal,
      });
    }
    return finished(response.ok || response.status === 401);
  } catch {
    return finished(false);
  } finally {
    window.clearTimeout(timeout);
  }
}
