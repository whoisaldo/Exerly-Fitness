import { useCallback, useEffect, useRef, useState } from 'react';
import { ApiError } from '../lib/api';
import { subscribeToReconnect } from '../lib/offlineCache';

interface State<T> {
  data: T | null;
  loading: boolean;
  error: string | null;
}

/**
 * Fetch-on-mount with refetch, cancellation, and a stable error string.
 *
 * `deps` behaves like a useEffect dependency list. An in-flight request is
 * aborted when the deps change, so switching days quickly can't leave a stale
 * response overwriting the current one.
 */
export function useResource<T>(
  fetcher: (signal: AbortSignal) => Promise<T>,
  deps: unknown[] = []
): State<T> & { refetch: () => void; setData: (value: T) => void } {
  const [state, setState] = useState<State<T>>({ data: null, loading: true, error: null });
  const [nonce, setNonce] = useState(0);
  useEffect(() => {
    const refresh = () => setNonce((n) => n + 1);
    return subscribeToReconnect(refresh);
  }, []);
  const fetcherRef = useRef(fetcher);
  fetcherRef.current = fetcher;

  useEffect(() => {
    const controller = new AbortController();
    let active = true;

    setState((prev) => ({ ...prev, loading: true, error: null }));

    fetcherRef
      .current(controller.signal)
      .then((data) => {
        if (active) setState({ data, loading: false, error: null });
      })
      .catch((err: unknown) => {
        if (!active || controller.signal.aborted) return;
        // A 401 has already cleared the token and triggered the redirect, so
        // showing an error banner on the way out would just be noise.
        if (err instanceof ApiError && err.status === 401) return;
        setState({
          data: null,
          loading: false,
          error: err instanceof Error ? err.message : 'Something went wrong',
        });
      });

    return () => {
      active = false;
      controller.abort();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, nonce]);

  const refetch = useCallback(() => setNonce((n) => n + 1), []);
  const setData = useCallback((value: T) => {
    setState({ data: value, loading: false, error: null });
  }, []);

  return { ...state, refetch, setData };
}

/**
 * Runs a mutation and reports whether it is in flight. Keeps every "save"
 * button in the app from reimplementing the same three pieces of state.
 */
export function useMutation<Args extends unknown[], R>(
  fn: (...args: Args) => Promise<R>
): { run: (...args: Args) => Promise<R | null>; pending: boolean; error: string | null } {
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fnRef = useRef(fn);
  fnRef.current = fn;
  const busy = useRef(false);

  const run = useCallback(async (...args: Args) => {
    if (busy.current) return null;
    busy.current = true;
    setPending(true);
    setError(null);
    try {
      return await fnRef.current(...args);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Something went wrong');
      return null;
    } finally {
      busy.current = false;
      setPending(false);
    }
  }, []);

  return { run, pending, error };
}
