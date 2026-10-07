import { useCallback, useEffect, useState, useSyncExternalStore } from 'react';
import { api, setUnauthorizedHandler } from '../lib/api';
import { getSessionScope, readSession, subscribeToSession } from '../lib/sessionStorage';
import type { UnitSystem } from '../lib/units';
import type { SetupStatus } from '../components/Onboarding/setupTypes';
import { subscribeToReconnect, validBootstrap } from '../lib/offlineCache';

export interface SessionUser {
  _id?: string;
  email: string;
  name: string | null;
  isAdmin: boolean;
  onboardingCompleted: boolean;
  age: number | null;
  gender: string | null;
  height: number | null;
  weight: number | null;
  goal: string | null;
  activityLevel?: string | null;
  targetWeight?: number | null;
  timezone: string;
  unitSystem: UnitSystem;
  preferencesRevision?: number;
}

interface Session {
  scope: string;
  user: SessionUser;
  setup: SetupStatus;
  features: Record<string, boolean>;
}
interface Bootstrap {
  account: SessionUser;
  account_id: string;
  onboarding: SetupStatus;
  features: Record<string, boolean>;
  contract_version: number;
}
let cachedSession: Session | null = null;
let inFlight: { scope: string; promise: Promise<Session | null> } | null = null;
let generation = 0;
const profileListeners = new Set<() => void>();

function loadSession(scope: string, force: boolean): Promise<Session | null> {
  if (!force && cachedSession?.scope === scope) return Promise.resolve(cachedSession);
  if (inFlight?.scope === scope) return inFlight.promise;
  const requestGeneration = generation;
  const promise = api
    .get<Bootstrap>('/api/bootstrap', { offlineFallback: true })
    .then((bootstrap) => {
      if (generation !== requestGeneration || getSessionScope() !== scope) return null;
      if (
        !validBootstrap(bootstrap) ||
        !bootstrap.account?._id ||
        String(bootstrap.account_id) !== String(bootstrap.account._id) ||
        String(bootstrap.onboarding?.user?._id) !== String(bootstrap.account._id) ||
        typeof bootstrap.onboarding.complete !== 'boolean'
      )
        throw new Error('Could not confirm your account setup. Retry to load it again.');
      const session = {
        scope,
        user: bootstrap.account,
        setup: bootstrap.onboarding,
        features: bootstrap.features ?? {},
      };
      cachedSession = session;
      return session;
    })
    .catch((error) => {
      if (generation !== requestGeneration || getSessionScope() !== scope) return null;
      throw error;
    })
    .finally(() => {
      if (inFlight?.promise === promise) inFlight = null;
    });
  inFlight = { scope, promise };
  return promise;
}

export function useSessionScope(): string | null {
  return useSyncExternalStore(subscribeToSession, getSessionScope, () => null);
}

function credentialSnapshot(): string | null {
  const session = readSession();
  return session ? `${session.token}\n${session.refreshToken ?? ''}` : null;
}

export function useSession(): {
  user: SessionUser | null;
  setup: SetupStatus | null;
  features: Record<string, boolean>;
  loading: boolean;
  error: string | null;
  retry: () => void;
  unitSystem: UnitSystem;
} {
  const scope = useSessionScope();
  const credential = useSyncExternalStore(subscribeToSession, credentialSnapshot, () => null);
  const [attempt, setAttempt] = useState(0);
  const retry = useCallback(() => setAttempt((value) => value + 1), []);
  useEffect(() => subscribeToReconnect(retry), [retry]);
  const [state, setState] = useState<{
    scope: string | null;
    user: SessionUser | null;
    setup: SetupStatus | null;
    features: Record<string, boolean>;
    loading: boolean;
    error: string | null;
  }>(() => ({
    scope,
    user: cachedSession?.scope === scope ? cachedSession.user : null,
    setup: cachedSession?.scope === scope ? cachedSession.setup : null,
    features: cachedSession?.scope === scope ? cachedSession.features : {},
    loading: !!scope && cachedSession?.scope !== scope,
    error: null,
  }));

  useEffect(() => {
    let active = true;
    if (!scope) {
      setState({ scope: null, user: null, setup: null, features: {}, loading: false, error: null });
      return;
    }
    setState({
      scope,
      user: cachedSession?.scope === scope ? cachedSession.user : null,
      setup: cachedSession?.scope === scope ? cachedSession.setup : null,
      features: cachedSession?.scope === scope ? cachedSession.features : {},
      loading: cachedSession?.scope !== scope,
      error: null,
    });
    const receiveProfile = () => {
      if (active && cachedSession?.scope === scope && getSessionScope() === scope)
        setState({ ...cachedSession, loading: false, error: null });
    };
    profileListeners.add(receiveProfile);
    void loadSession(scope, attempt > 0)
      .then((session) => {
        if (active && session && getSessionScope() === session.scope)
          setState({ ...session, loading: false, error: null });
      })
      .catch((error) => {
        if (active && getSessionScope() === scope)
          setState({
            scope,
            user: null,
            setup: null,
            features: {},
            loading: false,
            error:
              error instanceof Error ? error.message : 'Could not load your account. Try again.',
          });
      });
    return () => {
      active = false;
      profileListeners.delete(receiveProfile);
    };
  }, [scope, attempt, credential]);

  const user = state.scope === scope ? state.user : null;
  return {
    user,
    setup: state.scope === scope ? state.setup : null,
    features: state.scope === scope ? state.features : {},
    loading: !!scope && (state.scope !== scope || state.loading),
    error: state.scope === scope ? state.error : null,
    retry,
    unitSystem: user?.unitSystem ?? 'metric',
  };
}

export function acceptSetupCompletion(scope: string, setup: SetupStatus): void {
  if (
    getSessionScope() !== scope ||
    !setup.complete ||
    !setup.targets ||
    !setup.user._id ||
    (cachedSession?.scope === scope && cachedSession.user._id !== setup.user._id)
  )
    return;
  generation += 1;
  inFlight = null;
  cachedSession = {
    scope,
    user: setup.user,
    setup,
    features: cachedSession?.scope === scope ? cachedSession.features : {},
  };
  for (const listener of profileListeners) listener();
}

export function acceptProfile(scope: string, user: SessionUser): void {
  if (
    getSessionScope() !== scope ||
    cachedSession?.scope !== scope ||
    !user._id ||
    cachedSession.user._id !== user._id ||
    (cachedSession.user.preferencesRevision ?? 0) > (user.preferencesRevision ?? 0)
  )
    return;
  generation += 1;
  inFlight = null;
  cachedSession = { ...cachedSession, user, setup: { ...cachedSession.setup, user } };
  for (const listener of profileListeners) listener();
}

export function clearSessionCache(): void {
  generation += 1;
  cachedSession = null;
  inFlight = null;
}

export function installSessionGuard(navigate: (path: string) => void): void {
  setUnauthorizedHandler(() => {
    clearSessionCache();
    navigate('/login');
  });
}
