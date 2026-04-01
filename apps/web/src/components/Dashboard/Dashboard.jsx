// frontend/src/components/Dashboard/Dashboard.jsx
import React, { useEffect, useMemo, useState, useCallback } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import API_CONFIG from '../../config';
import {
  GlassCard,
  StatCard,
  PageHeader,
  ActionButton,
  Badge,
  ProgressRing,
  EmptyState,
  LoadingSkeleton,
  PageTransition,
} from '../ui';

const BASE_URL = API_CONFIG.BASE_URL;

// Enhanced JWT decoder
function decodeJWT(token) {
  try {
    const base64Url = token.split('.')[1];
    const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
    const json = decodeURIComponent(
      atob(base64)
        .split('')
        .map(c => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
        .join('')
    );
    return JSON.parse(json);
  } catch {
    return null;
  }
}

function useCountUp(target, duration = 1500) {
  const [value, setValue] = useState(0);
  useEffect(() => {
    if (!target) return;
    let start = 0;
    const increment = target / (duration / 16);
    const timer = setInterval(() => {
      start += increment;
      if (start >= target) { setValue(target); clearInterval(timer); }
      else setValue(Math.floor(start));
    }, 16);
    return () => clearInterval(timer);
  }, [target, duration]);
  return value;
}

// Small animated stat number used in the today summary bar
function AnimatedNumber({ value }) {
  const num = typeof value === 'number' ? value : parseInt(String(value).replace(/[^0-9-]/g, ''), 10) || 0;
  const display = useCountUp(Math.abs(num));
  return <>{num < 0 ? '-' : ''}{display}</>;
}

const cardIconMap = {
  'Total Workouts': (
    <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
    </svg>
  ),
  'Calories Burned': (
    <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M15.362 5.214A8.252 8.252 0 0112 21 8.25 8.25 0 016.038 7.048 8.287 8.287 0 009 9.6a8.983 8.983 0 013.361-6.867 8.21 8.21 0 003 2.48z" />
    </svg>
  ),
  'Calories Consumed': (
    <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M12 8.25v-1.5m0 1.5c-1.355 0-2.697.056-4.024.166C6.845 8.51 6 9.473 6 10.608v2.513m6-4.871c1.355 0 2.697.056 4.024.166C17.155 8.51 18 9.473 18 10.608v2.513M15 8.25v-1.5m-6 1.5v-1.5m12 9.75l-1.5.75a3.354 3.354 0 01-3 0 3.354 3.354 0 00-3 0 3.354 3.354 0 01-3 0 3.354 3.354 0 00-3 0 3.354 3.354 0 01-3 0L3 16.5m15-3.379a48.474 48.474 0 00-6-.371c-2.032 0-4.034.126-6 .371m12 0c.39.049.777.102 1.163.16 1.07.16 1.837 1.094 1.837 2.175v5.169c0 .621-.504 1.125-1.125 1.125H4.125A1.125 1.125 0 013 20.625v-5.17c0-1.08.768-2.014 1.837-2.174A47.78 47.78 0 016 13.12M12.265 3.11a.375.375 0 11-.53 0L12 2.845l.265.265z" />
    </svg>
  ),
  'Sleep (hrs)': (
    <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M21.752 15.002A9.718 9.718 0 0118 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.33.266-2.597.748-3.752A9.753 9.753 0 003 11.25C3 16.635 7.365 21 12.75 21a9.753 9.753 0 009.002-5.998z" />
    </svg>
  ),
  Goals: (
    <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M3 3v1.5M3 21v-6m0 0l2.77-.693a9 9 0 016.208.682l.108.054a9 9 0 006.086.71l3.114-.732a48.524 48.524 0 01-.005-10.499l-3.11.732a9 9 0 01-6.085-.711l-.108-.054a9 9 0 00-6.208-.682L3 4.5M3 15V4.5" />
    </svg>
  ),
  Maintenance: (
    <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M12 3v17.25m0 0c-1.472 0-2.882.265-4.185.75M12 20.25c1.472 0 2.882.265 4.185.75M18.75 4.97A48.416 48.416 0 0012 4.5c-2.291 0-4.545.16-6.75.47m13.5 0c1.01.143 2.01.317 3 .52m-3-.52l2.62 10.726c.122.499-.106 1.028-.589 1.202a5.988 5.988 0 01-2.031.352 5.988 5.988 0 01-2.031-.352c-.483-.174-.711-.703-.59-1.202L18.75 4.971zm-16.5.52c.99-.203 1.99-.377 3-.52m0 0l2.62 10.726c.122.499-.106 1.028-.589 1.202a5.989 5.989 0 01-2.031.352 5.989 5.989 0 01-2.031-.352c-.483-.174-.711-.703-.59-1.202L5.25 4.971z" />
    </svg>
  ),
  'Net vs. Maint.': (
    <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z" />
    </svg>
  ),
  Admin: (
    <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
    </svg>
  ),
};

const entryTypeIcons = {
  food: (
    <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M12 8.25v-1.5m0 1.5c-1.355 0-2.697.056-4.024.166C6.845 8.51 6 9.473 6 10.608v2.513m6-4.871c1.355 0 2.697.056 4.024.166C17.155 8.51 18 9.473 18 10.608v2.513M15 8.25v-1.5m-6 1.5v-1.5m12 9.75l-1.5.75a3.354 3.354 0 01-3 0 3.354 3.354 0 00-3 0 3.354 3.354 0 01-3 0 3.354 3.354 0 00-3 0 3.354 3.354 0 01-3 0L3 16.5m15-3.379a48.474 48.474 0 00-6-.371c-2.032 0-4.034.126-6 .371m12 0c.39.049.777.102 1.163.16 1.07.16 1.837 1.094 1.837 2.175v5.169c0 .621-.504 1.125-1.125 1.125H4.125A1.125 1.125 0 013 20.625v-5.17c0-1.08.768-2.014 1.837-2.174A47.78 47.78 0 016 13.12" />
    </svg>
  ),
  activity: (
    <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
    </svg>
  ),
  sleep: (
    <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M21.752 15.002A9.718 9.718 0 0118 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.33.266-2.597.748-3.752A9.753 9.753 0 003 11.25C3 16.635 7.365 21 12.75 21a9.753 9.753 0 009.002-5.998z" />
    </svg>
  ),
};

const entryTypeBg = {
  food: 'bg-emerald-500/20 text-emerald-400',
  activity: 'bg-violet-500/20 text-violet-400',
  sleep: 'bg-indigo-500/20 text-indigo-400',
};

export default function Dashboard() {
  const [stats, setStats] = useState([]);
  const [recent, setRecent] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState('');
  const [goals, setGoals] = useState(null);
  const [goalsProgress, setGoalsProgress] = useState(null);
  const navigate = useNavigate();

  const token = localStorage.getItem('token');
  const payload = useMemo(() => (token ? decodeJWT(token) : null), [token]);

  const firstName = useMemo(() => {
    const name = payload?.name || '';
    return name.trim().split(' ')[0] || '';
  }, [payload]);

  const email = payload?.email?.toLowerCase() || '';
  const isAdmin = !!payload?.is_admin ||
    (import.meta.env.VITE_ADMIN_EMAILS || '')
      .toLowerCase()
      .split(',')
      .map(s => s.trim())
      .filter(Boolean)
      .includes(email);

  const cards = useMemo(() => (
    isAdmin
      ? [{ label: 'Admin', value: 'Open', route: '/dashboard/admin', icon: '👑', color: 'admin' }, ...stats]
      : stats
  ), [stats, isAdmin]);

  const fetchDashboard = useCallback(async (showRefreshing = false) => {
    if (!token) {
      navigate('/');
      return;
    }

    if (showRefreshing) setRefreshing(true);

    try {
      setError('');
      const headers = { Authorization: 'Bearer ' + token };

      const [dashRes, recentRes] = await Promise.all([
        fetch(`${BASE_URL}/api/dashboard-data?t=${Date.now()}`, { headers, cache: 'no-store' }),
        fetch(`${BASE_URL}/api/recent?t=${Date.now()}`, { headers, cache: 'no-store' }),
      ]);

      if (dashRes.status === 401 || recentRes.status === 401) {
        navigate('/');
        return;
      }

      if (!dashRes.ok) throw new Error(`Dashboard data failed: ${dashRes.status}`);

      const dashRaw = await dashRes.json();
      let recentRaw = recentRes.ok ? await recentRes.json() : [];



      // Normalize dashboard totals
      let totals = {
        totalBurned: 0,
        workoutCount: 0,
        totalConsumed: 0,
        totalSleepHours: 0,
        maintenance: 0,
        net: 0,
      };

      if (Array.isArray(dashRaw)) {
        // Old array shape fallback
        const pick = (labelPart) => {
          const item = dashRaw.find(x => x.label?.toLowerCase().includes(labelPart));
          if (!item) return 0;
          const m = String(item.value ?? '').match(/-?\d+(\.\d+)?/);
          return m ? Number(m[0]) : 0;
        };
        totals = {
          workoutCount: pick('workout'),
          totalBurned: pick('burned'),
          totalConsumed: pick('consumed'),
          totalSleepHours: pick('sleep'),
          maintenance: pick('maintenance'),
          net: pick('net'),
        };
      } else {
        // New object shape from backend
        totals = {
          totalBurned: Number(dashRaw.totalBurned ?? 0),
          workoutCount: Number(dashRaw.workoutCount ?? 0),
          totalConsumed: Number(dashRaw.totalConsumed ?? 0),
          totalSleepHours: Number(dashRaw.totalSleepHours ?? 0),
          maintenance: Number(dashRaw.maintenance ?? 0),
          net: Number(dashRaw.net ?? 0),
        };
      }

             // Process recent logs from backend
       let recentList = [];
       if (Array.isArray(recentRaw) && recentRaw.length > 0) {
         // Process the data from /api/recent endpoint
         recentList = recentRaw.map(entry => {
                       // Add safety checks for entry
            if (!entry || typeof entry !== 'object') {
              return null;
            }

           if (entry.type === 'food') {
             return {
               type: 'food',
               calories: Number(entry.calories) || 0,
               label: `${entry.name || 'Unknown Food'} • ${entry.calories || 0} calories`,
               ts: entry.id || 0,
               icon: '🍽️'
             };
           } else if (entry.type === 'activity') {
             return {
               type: 'activity',
               calories: -(Number(entry.calories) || 0),
               label: `${entry.activity || 'Unknown Activity'} • ${entry.calories || 0} calories`,
               ts: entry.id || 0,
               icon: '💪'
             };
           } else if (entry.type === 'sleep') {
             return {
               type: 'sleep',
               calories: 0,
               label: `${entry.hours || 0}h ${entry.quality || ''}`.trim(),
               ts: entry.id || 0,
               icon: '😴'
             };
           }

                       return null;
         }).filter(Boolean); // Remove any null entries

         // Sort by timestamp
         recentList.sort((a, b) => (b.ts || 0) - (a.ts || 0));
       } else {
        // Fallback: fetch individual endpoints if /api/recent is empty
        const [actsRes, foodRes, sleepRes] = await Promise.all([
          fetch(`${BASE_URL}/api/activities`, { headers, cache: 'no-store' }),
          fetch(`${BASE_URL}/api/food`, { headers, cache: 'no-store' }),
          fetch(`${BASE_URL}/api/sleep`, { headers, cache: 'no-store' }),
        ]);

        const [acts, foods, sleeps] = await Promise.all([
          actsRes.ok ? actsRes.json() : Promise.resolve([]),
          foodRes.ok ? foodRes.json() : Promise.resolve([]),
          sleepRes.ok ? sleepRes.json() : Promise.resolve([]),
        ]);

        const today = new Date().toISOString().slice(0, 10);

        const foodsToday = (Array.isArray(foods) ? foods : [])
          .filter(f => f.entry_date === today)
          .map(f => ({
            type: 'food',
            calories: Number(f.calories) || 0,
            label: `${f.name} • ${f.calories} calories`,
            ts: f.id || 0,
            icon: '🍽️'
          }));

        const actsToday = (Array.isArray(acts) ? acts : [])
          .filter(a => a.entry_date === today)
          .map(a => ({
            type: 'activity',
            calories: -(Number(a.calories) || 0),
            label: `${a.activity} • ${a.calories} calories`,
            ts: a.id || 0,
            icon: '💪'
          }));

        const sleepsToday = (Array.isArray(sleeps) ? sleeps : [])
          .filter(s => s.entry_date === today)
          .map(s => ({
            type: 'sleep',
            calories: 0,
            label: `${s.hours}h ${s.quality || ''}`.trim(),
            ts: s.id || 0,
            icon: '😴'
          }));

        recentList = [...foodsToday, ...actsToday, ...sleepsToday]
          .sort((a, b) => (b.ts || 0) - (a.ts || 0))
          .slice(0, 20);
      }

      setStats([
        {
          label: 'Total Workouts',
          value: `${totals.workoutCount}`,
          route: '/dashboard/activities',
          icon: '💪',
          color: 'workout'
        },
        {
          label: 'Calories Burned',
          value: `${totals.totalBurned} calories`,
          route: '/dashboard/activities',
          icon: '🔥',
          color: 'burned'
        },
        {
          label: 'Calories Consumed',
          value: `${totals.totalConsumed} calories`,
          route: '/dashboard/food',
          icon: '🍽️',
          color: 'consumed'
        },
        {
          label: 'Sleep (hrs)',
          value: `${totals.totalSleepHours}h`,
          route: '/dashboard/sleep',
          icon: '😴',
          color: 'sleep'
        },
        {
          label: 'Goals',
          value: 'Set & Track',
          route: '/dashboard/goals',
          icon: '🎯',
          color: 'goals'
        },
        {
          label: 'Maintenance',
          value: `${totals.maintenance} calories`,
          route: '/dashboard/profile',
          icon: '⚖️',
          color: 'maintenance'
        },
        {
          label: 'Net vs. Maint.',
          value: `${totals.net >= 0 ? '+' : ''}${totals.net} calories`,
          route: '/dashboard',
          icon: '📊',
          color: totals.net >= 0 ? 'positive' : 'negative'
        },
      ]);

      setRecent(recentList);
    } catch (err) {
      console.error('Dashboard fetch failed:', err);
      setError('Failed to load dashboard data. Please try again.');
      setStats([
        { label: 'Total Workouts', value: '0', route: '/dashboard/activities', icon: '💪', color: 'workout' },
        { label: 'Calories Burned', value: '0 calories', route: '/dashboard/activities', icon: '🔥', color: 'burned' },
        { label: 'Calories Consumed', value: '0 calories', route: '/dashboard/food', icon: '🍽️', color: 'consumed' },
        { label: 'Sleep (hrs)', value: '0h', route: '/dashboard/sleep', icon: '😴', color: 'sleep' },
        { label: 'Goals', value: 'Set & Track', route: '/dashboard/goals', icon: '🎯', color: 'goals' },
        { label: 'Maintenance', value: '0 calories', route: '/dashboard/profile', icon: '⚖️', color: 'maintenance' },
        { label: 'Net vs. Maint.', value: '+0 calories', route: '/dashboard', icon: '📊', color: 'positive' },
      ]);
      setRecent([]);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [navigate, token]);

  const fetchGoals = useCallback(async () => {
    if (!token) return;
    try {
      const [goalsRes, dashDataRes] = await Promise.all([
        fetch(`${BASE_URL}/api/goals`, { headers: { Authorization: 'Bearer ' + token } }),
        fetch(`${BASE_URL}/api/dashboard-data`, { headers: { Authorization: 'Bearer ' + token } })
      ]);

      if (goalsRes.ok) {
        const goalsData = await goalsRes.json();
        setGoals(goalsData);

        // Calculate progress if we have dashboard data
        if (dashDataRes.ok) {
          const dashData = await dashDataRes.json();
          const progress = {};

          // Weekly workouts progress (from today's workout count)
          if (goalsData.weekly_workouts) {
            progress.weeklyWorkouts = {
              current: dashData.workoutCount || 0,
              goal: goalsData.weekly_workouts,
              percentage: Math.min(100, ((dashData.workoutCount || 0) / goalsData.weekly_workouts) * 100)
            };
          }

          // Daily calories progress
          if (goalsData.daily_calories) {
            progress.dailyCalories = {
              current: dashData.totalConsumed || 0,
              goal: goalsData.daily_calories,
              percentage: Math.min(100, ((dashData.totalConsumed || 0) / goalsData.daily_calories) * 100)
            };
          }

          // Sleep hours progress
          if (goalsData.sleep_hours) {
            progress.sleepHours = {
              current: dashData.totalSleepHours || 0,
              goal: goalsData.sleep_hours,
              percentage: Math.min(100, ((dashData.totalSleepHours || 0) / goalsData.sleep_hours) * 100)
            };
          }

          setGoalsProgress(progress);
        }
      }
    } catch (err) {
      console.error('Error fetching goals:', err);
    }
  }, [token]);

  useEffect(() => {
    fetchDashboard();
    fetchGoals();
  }, [fetchDashboard, fetchGoals]);

  useEffect(() => {
    const onFocus = () => fetchDashboard();
    const onVisibility = () => {
      if (!document.hidden) fetchDashboard();
    };

    window.addEventListener('focus', onFocus);
    document.addEventListener('visibilitychange', onVisibility);

    return () => {
      window.removeEventListener('focus', onFocus);
      document.removeEventListener('visibilitychange', onVisibility);
    };
  }, [fetchDashboard]);

  const handleResetToday = async () => {
    if (!window.confirm("Reset today's entries? This cannot be undone.")) {
      return;
    }

    const token = localStorage.getItem('token');
    if (!token) return navigate('/');

    try {
      setRefreshing(true);
      const res = await fetch(`${BASE_URL}/api/reset-today`, {
        method: 'POST',
        headers: { Authorization: 'Bearer ' + token }
      });

      if (!res.ok) throw new Error(`HTTP ${res.status}`);

      await fetchDashboard();
      setError('');
    } catch (e) {
      console.error('Reset failed', e);
      setError('Failed to reset today. Please try again.');
    } finally {
      setRefreshing(false);
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('token');
    navigate('/');
  };

  const handleRefresh = () => {
    fetchDashboard(true);
  };

  // Extract numeric values for the today summary bar
  const consumed = parseInt(String(stats.find(s => s.label === 'Calories Consumed')?.value).replace(/[^0-9]/g, ''), 10) || 0;
  const burned = parseInt(String(stats.find(s => s.label === 'Calories Burned')?.value).replace(/[^0-9]/g, ''), 10) || 0;
  const workouts = parseInt(String(stats.find(s => s.label === 'Total Workouts')?.value).replace(/[^0-9]/g, ''), 10) || 0;

  const consumedAnim = useCountUp(consumed);
  const burnedAnim = useCountUp(burned);

  const dateStr = new Date().toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
  });

  return (
    <PageTransition className="min-h-screen bg-deep px-4 pb-24 pt-6 sm:px-6 lg:px-8">
      {/* ---- GREETING HEADER ---- */}
      <header className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-label text-slate-400">{dateStr}</p>
          <h1 className="text-display-sm mt-1 text-slate-50">
            Welcome back, {firstName || 'Fitness Warrior'}!
          </h1>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <ActionButton
            variant="ghost"
            loading={refreshing}
            onClick={handleRefresh}
            disabled={refreshing}
            icon={
              <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182" />
              </svg>
            }
            className="h-11"
          >
            <span className="hidden sm:inline">Refresh</span>
          </ActionButton>

          {isAdmin && (
            <ActionButton
              variant="secondary"
              onClick={() => navigate('/dashboard/admin')}
              icon={
                <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
                </svg>
              }
              className="h-11"
            >
              Admin
            </ActionButton>
          )}

          <ActionButton
            variant="ghost"
            onClick={handleResetToday}
            disabled={refreshing}
            className="h-11 text-warning"
          >
            Reset Today
          </ActionButton>

          <ActionButton
            variant="ghost"
            onClick={handleLogout}
            icon={
              <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15m3 0l3-3m0 0l-3-3m3 3H9" />
              </svg>
            }
            className="h-11"
          >
            Logout
          </ActionButton>
        </div>
      </header>

      {/* ---- ERROR BANNER ---- */}
      <AnimatePresence>
        {error && (
          <motion.div
            initial={{ opacity: 0, y: -8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            className="mt-4 flex items-center justify-between gap-3 rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error"
          >
            <span>{error}</span>
            <button onClick={() => setError('')} className="shrink-0 rounded-lg p-1 hover:bg-error/20">
              <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ---- TODAY SUMMARY BAR ---- */}
      {!loading && (
        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
        >
          <GlassCard elevated className="mt-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-around" hover={false}>
            <div className="flex items-center gap-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-500/15">
                <svg className="h-5 w-5 text-emerald-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M12 8.25v-1.5m0 1.5c-1.355 0-2.697.056-4.024.166C6.845 8.51 6 9.473 6 10.608v2.513m6-4.871c1.355 0 2.697.056 4.024.166C17.155 8.51 18 9.473 18 10.608v2.513M15 8.25v-1.5m-6 1.5v-1.5m12 9.75l-1.5.75a3.354 3.354 0 01-3 0 3.354 3.354 0 00-3 0 3.354 3.354 0 01-3 0 3.354 3.354 0 00-3 0 3.354 3.354 0 01-3 0L3 16.5m15-3.379a48.474 48.474 0 00-6-.371c-2.032 0-4.034.126-6 .371m12 0c.39.049.777.102 1.163.16 1.07.16 1.837 1.094 1.837 2.175v5.169c0 .621-.504 1.125-1.125 1.125H4.125A1.125 1.125 0 013 20.625v-5.17c0-1.08.768-2.014 1.837-2.174A47.78 47.78 0 016 13.12" />
                </svg>
              </div>
              <div>
                <p className="text-label text-slate-400">Consumed</p>
                <p className="text-xl font-bold text-slate-50">{consumedAnim} <span className="text-sm font-normal text-slate-400">cal</span></p>
              </div>
            </div>

            <div className="hidden h-8 w-px bg-white/10 sm:block" />

            <div className="flex items-center gap-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-orange-500/15">
                <svg className="h-5 w-5 text-orange-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M15.362 5.214A8.252 8.252 0 0112 21 8.25 8.25 0 016.038 7.048 8.287 8.287 0 009 9.6a8.983 8.983 0 013.361-6.867 8.21 8.21 0 003 2.48z" />
                </svg>
              </div>
              <div>
                <p className="text-label text-slate-400">Burned</p>
                <p className="text-xl font-bold text-slate-50">{burnedAnim} <span className="text-sm font-normal text-slate-400">cal</span></p>
              </div>
            </div>

            <div className="hidden h-8 w-px bg-white/10 sm:block" />

            <div className="flex items-center gap-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-violet-500/15">
                <svg className="h-5 w-5 text-violet-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
                </svg>
              </div>
              <div>
                <p className="text-label text-slate-400">Workouts</p>
                <p className="text-xl font-bold text-slate-50">{workouts}</p>
              </div>
            </div>
          </GlassCard>
        </motion.div>
      )}

      {/* ---- STAT CARDS GRID ---- */}
      <section className="mt-8">
        <h2 className="mb-4 text-lg font-semibold text-slate-200">Today's Overview</h2>

        {loading ? (
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
            <LoadingSkeleton variant="stat" count={7} />
          </div>
        ) : cards.length === 0 ? (
          <EmptyState
            icon={
              <svg className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75z" />
              </svg>
            }
            title="No data yet"
            message="Start logging your workouts, food, and sleep to see your insights here."
            action={{ label: 'Log Workout', onClick: () => navigate('/dashboard/activities') }}
          />
        ) : (
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
            {cards.map(({ label, value, route, icon, color }, index) => (
              <motion.div
                key={label}
                initial={{ opacity: 0, y: 16 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: index * 0.05 }}
              >
                <Link to={route} className="block">
                  <StatCard
                    icon={cardIconMap[label] || <span className="text-base">{icon}</span>}
                    label={label}
                    value={value}
                    className={`h-full min-h-[7rem] ${color === 'negative' ? 'border-error/20' : ''}`}
                  />
                </Link>
              </motion.div>
            ))}
          </div>
        )}
      </section>

      {/* ---- GOALS PROGRESS ---- */}
      {goalsProgress && Object.keys(goalsProgress).length > 0 && (
        <motion.section
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="mt-8"
        >
          <div className="mb-4 flex items-center justify-between">
            <h2 className="text-lg font-semibold text-slate-200">Goals Progress</h2>
            <Link
              to="/dashboard/goals"
              className="text-sm font-medium text-primary-bright transition-colors hover:text-primary"
            >
              Manage Goals &rarr;
            </Link>
          </div>

          <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
            {goalsProgress.weeklyWorkouts && (
              <GlassCard className="flex flex-col items-center gap-3 text-center">
                <ProgressRing
                  value={goalsProgress.weeklyWorkouts.percentage}
                  size={88}
                  label="Workouts"
                />
                <p className="text-sm text-slate-300">
                  <span className="font-semibold text-slate-50">
                    {goalsProgress.weeklyWorkouts.current}
                  </span>
                  {' / '}
                  {goalsProgress.weeklyWorkouts.goal} weekly workouts
                </p>
              </GlassCard>
            )}

            {goalsProgress.dailyCalories && (
              <GlassCard className="flex flex-col items-center gap-3 text-center">
                <ProgressRing
                  value={goalsProgress.dailyCalories.percentage}
                  size={88}
                  label="Calories"
                />
                <p className="text-sm text-slate-300">
                  <span className="font-semibold text-slate-50">
                    {goalsProgress.dailyCalories.current}
                  </span>
                  {' / '}
                  {goalsProgress.dailyCalories.goal} cal
                </p>
              </GlassCard>
            )}

            {goalsProgress.sleepHours && (
              <GlassCard className="flex flex-col items-center gap-3 text-center">
                <ProgressRing
                  value={goalsProgress.sleepHours.percentage}
                  size={88}
                  label="Sleep"
                />
                <p className="text-sm text-slate-300">
                  <span className="font-semibold text-slate-50">
                    {goalsProgress.sleepHours.current}h
                  </span>
                  {' / '}
                  {goalsProgress.sleepHours.goal}h sleep
                </p>
              </GlassCard>
            )}
          </div>
        </motion.section>
      )}

      {/* ---- TODAY'S ACTIVITY LOG ---- */}
      <motion.section
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.3 }}
        className="mt-8"
      >
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-slate-200">Today's Activity Log</h2>
          <Badge variant="status">{recent.length} entries</Badge>
        </div>

        <GlassCard hover={false}>
          {recent.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-10 text-center">
              <div className="mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-primary/10 text-primary">
                <svg className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10" />
                </svg>
              </div>
              <h3 className="text-lg font-semibold text-slate-200">No activities logged today</h3>
              <p className="mt-1 max-w-xs text-sm text-slate-400">
                Start your day by logging your first activity!
              </p>
              <div className="mt-5 flex flex-wrap justify-center gap-2">
                <Link to="/dashboard/activities">
                  <ActionButton variant="secondary" className="h-11">Log Workout</ActionButton>
                </Link>
                <Link to="/dashboard/food">
                  <ActionButton variant="secondary" className="h-11">Log Food</ActionButton>
                </Link>
                <Link to="/dashboard/sleep">
                  <ActionButton variant="secondary" className="h-11">Log Sleep</ActionButton>
                </Link>
                <Link to="/dashboard/goals">
                  <ActionButton variant="secondary" className="h-11">Set Goals</ActionButton>
                </Link>
              </div>
            </div>
          ) : (
            <div className="relative space-y-0">
              {recent.map((entry, index) => (
                <div
                  key={`${entry.type}-${index}`}
                  className="group relative flex items-start gap-3 py-3"
                >
                  {/* Timeline line */}
                  {index < recent.length - 1 && (
                    <div className="absolute left-5 top-12 h-[calc(100%-1.5rem)] w-px bg-white/5" />
                  )}
                  {/* Icon dot */}
                  <div
                    className={`relative z-10 flex h-10 w-10 shrink-0 items-center justify-center rounded-xl ${entryTypeBg[entry.type] || 'bg-white/10 text-slate-400'}`}
                  >
                    {entryTypeIcons[entry.type] || <span className="text-sm">{entry.icon}</span>}
                  </div>
                  {/* Content */}
                  <div className="min-w-0 flex-1 pt-0.5">
                    <p className="truncate text-sm font-medium text-slate-200">{entry.label}</p>
                    <p className="mt-0.5 text-xs text-slate-400">
                      {entry.type === 'sleep' ? (
                        entry.label
                      ) : (
                        <span className={entry.calories >= 0 ? 'text-success' : 'text-error'}>
                          {entry.calories >= 0 ? '+' : ''}{entry.calories} cal
                        </span>
                      )}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </GlassCard>
      </motion.section>

      {/* ---- AI COACH TEASER ---- */}
      <motion.section
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.4 }}
        className="mt-8"
      >
        <div className="relative overflow-hidden rounded-2xl border border-violet-500/20 bg-gradient-to-br from-violet-600/10 via-fuchsia-600/5 to-transparent p-6 shadow-glow-primary sm:p-8">
          <div className="absolute -right-12 -top-12 h-40 w-40 rounded-full bg-violet-500/10 blur-3xl" />
          <div className="absolute -bottom-8 -left-8 h-32 w-32 rounded-full bg-fuchsia-500/10 blur-3xl" />

          <div className="relative flex flex-col items-start gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h3 className="text-lg font-bold text-slate-50">
                AI-Powered Coaching
              </h3>
              <p className="mt-1 max-w-md text-sm text-slate-400">
                Get personalized workout plans, nutrition advice, and smart insights powered by AI.
              </p>
            </div>
            <Link to="/dashboard/ai-coach">
              <ActionButton variant="primary" className="h-11 whitespace-nowrap">
                Try AI Coach
              </ActionButton>
            </Link>
          </div>
        </div>
      </motion.section>
    </PageTransition>
  );
}
