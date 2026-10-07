import { useEffect, useMemo, useState } from 'react';
import { useSession, useSessionScope } from './useSession';
import { subscribeToReconnect } from '../lib/offlineCache';
import { readFoods, subscribeFoods, syncFoods, type FoodDocument } from '../lib/foodStore';

export function useFoodOwner() {
  const { user } = useSession();
  const scope = useSessionScope();
  const account = user?._id;
  return useMemo(() => (account && scope ? { account, scope } : null), [account, scope]);
}
export function useFoods() {
  const owner = useFoodOwner();
  const [state, setState] = useState<{
    account: string;
    doc: FoodDocument | null;
    error: string | null;
  }>({ account: '', doc: null, error: null });
  useEffect(() => {
    if (!owner) return;
    let active = true;
    let sequence = 0;
    const reload = () => {
      const attempt = ++sequence;
      void readFoods(owner.account)
        .then((doc) => {
          if (active && sequence === attempt)
            setState({ account: owner.account, doc, error: null });
        })
        .catch((error) => {
          if (active && sequence === attempt)
            setState({ account: owner.account, doc: null, error: error.message });
        });
    };
    reload();
    const unsubscribe = subscribeFoods(owner.account, reload);
    return () => {
      active = false;
      unsubscribe();
    };
  }, [owner]);
  return {
    owner,
    doc: state.account === owner?.account ? state.doc : null,
    error: state.account === owner?.account ? state.error : null,
  };
}

// Mounted with the authenticated account, so reconnecting on Home also replays
// food changes made in a previous diary visit or browser session.
export function FoodSync({ account, scope }: { account: string; scope: string }) {
  useEffect(() => {
    const owner = { account, scope };
    const replay = () => {
      void syncFoods(owner);
    };
    replay();
    return subscribeToReconnect(replay);
  }, [account, scope]);
  return null;
}
