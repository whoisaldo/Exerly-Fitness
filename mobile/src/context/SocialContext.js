import React, { createContext, useContext, useState, useCallback, useEffect, useRef, useMemo } from 'react';
import * as Social from '../services/SocialService';

const SocialContext = createContext(null);

export function SocialProvider({ children }) {
  const [friends, setFriends] = useState([]);
  const [challenges, setChallenges] = useState([]);
  const [loading, setLoading] = useState(false);
  const mounted = useRef(true);

  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; };
  }, []);

  const refresh = useCallback(async () => {
    setLoading(true);
    try {
      const [f, c] = await Promise.all([
        Social.getFriends().catch(() => []),
        Social.getChallenges().catch(() => []),
      ]);
      if (mounted.current) {
        setFriends(Array.isArray(f) ? f : []);
        setChallenges(Array.isArray(c) ? c : []);
      }
    } finally {
      if (mounted.current) setLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const value = useMemo(
    () => ({
      friends,
      challenges,
      loading,
      refresh,
      searchUser: Social.searchUser,
      addFriend: Social.addFriend,
      createChallenge: Social.createChallenge,
      getChallengeDetail: Social.getChallengeDetail,
      getFriendActivity: Social.getFriendActivity,
    }),
    [friends, challenges, loading, refresh],
  );

  return (
    <SocialContext.Provider value={value}>
      {children}
    </SocialContext.Provider>
  );
}

export function useSocial() {
  const ctx = useContext(SocialContext);
  if (!ctx) throw new Error('useSocial must be inside SocialProvider');
  return ctx;
}
