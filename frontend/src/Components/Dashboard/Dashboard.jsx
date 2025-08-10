// frontend/src/Components/Dashboard/Dashboard.jsx
import React, { useEffect, useMemo, useState, useCallback } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import '../LoginSignup/LoginSignup.css';
import './Dashboard.css';

const BASE_URL = process.env.REACT_APP_API_URL;
// Comma-separated admin email list from env
const ADMIN_EMAILS = (process.env.REACT_APP_ADMIN_EMAILS || '')
  .toLowerCase()
  .split(',')
  .map(s => s.trim())
  .filter(Boolean);

// Safe-ish JWT decode (no deps)
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

export default function Dashboard() {
  const [stats, setStats] = useState([]);
  const [recent, setRecent] = useState([]);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  const token = localStorage.getItem('token');
  // Decode once and reuse across the component
  const payload = useMemo(() => (token ? decodeJWT(token) : null), [token]);

  const firstName = useMemo(() => {
    const name = payload?.name || '';
    return name.trim().split(' ')[0] || '';
  }, [payload]);

  const email   = payload?.email?.toLowerCase() || '';
  const isAdmin = !!payload?.is_admin || ADMIN_EMAILS.includes(email);

  const cards = useMemo(() => (
    isAdmin
      ? [...stats, { label: 'Admin', value: 'Open', route: '/dashboard/admin' }]
      : stats
  ), [stats, isAdmin]);

  const fetchDashboard = useCallback(async () => {
    const token = localStorage.getItem('token');
    if (!token) { navigate('/'); return; }

    try {
      const headers = { Authorization: 'Bearer ' + token };
      // Hit both new endpoints together
      const [dashRes, recentRes] = await Promise.all([
        fetch(`${BASE_URL}/api/dashboard-data?t=${Date.now()}`, { headers, cache: 'no-store' }),
        fetch(`${BASE_URL}/api/recent?t=${Date.now()}`,          { headers, cache: 'no-store' }),
      ]);

      if (dashRes.status === 401 || recentRes.status === 401) { navigate('/'); return; }
      if (!dashRes.ok) throw new Error(`dashboard-data HTTP ${dashRes.status}`);

      const dashRaw   = await dashRes.json();
      let   recentRaw = recentRes.ok ? await recentRes.json() : [];

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
          workoutCount:     pick('workout'),
          totalBurned:      pick('burned'),
          totalConsumed:    pick('consumed'),
          totalSleepHours:  pick('sleep'),
          maintenance:      pick('maintenance'),
          net:              pick('net'),
        };
      } else {
        // New object shape from backend
        totals = {
          totalBurned:     Number(dashRaw.totalBurned ?? 0),
          workoutCount:    Number(dashRaw.workoutCount ?? 0),
          totalConsumed:   Number(dashRaw.totalConsumed ?? 0),
          totalSleepHours: Number(dashRaw.totalSleepHours ?? 0),
          maintenance:     Number(dashRaw.maintenance ?? 0),
          net:             Number(dashRaw.net ?? 0),
        };
      }

      // Robust fallback for Today’s Log if /api/recent empty or failed
      let recentList = Array.isArray(recentRaw) ? recentRaw : [];
      if (!recentList || recentList.length === 0) {
        const [actsRes, foodRes, sleepRes] = await Promise.all([
          fetch(`${BASE_URL}/api/activities`, { headers, cache: 'no-store' }),
          fetch(`${BASE_URL}/api/food`,       { headers, cache: 'no-store' }),
          fetch(`${BASE_URL}/api/sleep`,      { headers, cache: 'no-store' }),
        ]);
        const [acts, foods, sleeps] = await Promise.all([
          actsRes.ok ? actsRes.json() : Promise.resolve([]),
          foodRes.ok ? foodRes.json() : Promise.resolve([]),
          sleepRes.ok ? sleepRes.json() : Promise.resolve([]),
        ]);
        const today = new Date().toISOString().slice(0,10);

        const foodsToday = (Array.isArray(foods) ? foods : [])
          .filter(f => f.entry_date === today)
          .map(f => ({ type:'food', calories:Number(f.calories)||0, label: `${f.name} • ${f.calories} kcal`, ts: f.id || 0 }));

        const actsToday = (Array.isArray(acts) ? acts : [])
          .filter(a => a.entry_date === today)
          .map(a => ({ type:'activity', calories: -(Number(a.calories)||0), label: `${a.activity} • ${a.calories} kcal`, ts: a.id || 0 }));

        const sleepsToday = (Array.isArray(sleeps) ? sleeps : [])
          .filter(s => s.entry_date === today)
          .map(s => ({ type:'sleep', calories: 0, label: `${s.hours}h ${s.quality || ''}`.trim(), ts: s.id || 0 }));

        recentList = [...foodsToday, ...actsToday, ...sleepsToday]
          .sort((a,b) => (b.ts || 0) - (a.ts || 0))
          .slice(0, 20);
      }

      setStats([
        { label:'Total Workouts',    value: `${totals.workoutCount}`,              route:'/dashboard/activities' },
        { label:'Calories Burned',   value: `${totals.totalBurned} kcal`,          route:'/dashboard/activities' },
        { label:'Calories Consumed', value: `${totals.totalConsumed} kcal`,        route:'/dashboard/food' },
        { label:'Sleep (hrs)',       value: `${totals.totalSleepHours}h`,          route:'/dashboard/sleep' },
        { label:'Maintenance',       value: `${totals.maintenance} kcal`,          route:'/dashboard/profile' },
        { label:'Net',               value: `${totals.net >= 0 ? '+' : ''}${totals.net} kcal`, route:'/dashboard' },
      ]);
      setRecent(recentList);
    } catch (err) {
      console.error('dashboard fetch failed:', err);
      setStats([
        { label:'Total Workouts',    value: '0',          route:'/dashboard/activities' },
        { label:'Calories Burned',   value: '0 kcal',     route:'/dashboard/activities' },
        { label:'Calories Consumed', value: '0 kcal',     route:'/dashboard/food' },
        { label:'Sleep (hrs)',       value: '0h',         route:'/dashboard/sleep' },
        { label:'Maintenance',       value: '0 kcal',     route:'/dashboard/profile' },
        { label:'Net',               value: '+0 kcal',    route:'/dashboard' },
      ]);
      setRecent([]);
    } finally {
      setLoading(false);
    }
  }, [navigate]);

  useEffect(() => {
    fetchDashboard();
  }, [fetchDashboard]);

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
      const res = await fetch(`${BASE_URL}/api/reset-today`, {
        method: 'POST',
        headers: { Authorization: 'Bearer ' + token }
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      await fetchDashboard();
    } catch (e) {
      console.error('Reset failed', e);
      alert('Failed to reset today. Try again.');
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('token');
    navigate('/');
  };

  return (
    <div className="dashboard-page">
      {/* Hero Header */}
      <header className="header">
        <div className="dash-hero-left">
          <div className="text">Dashboard</div>
          <div className="underline"></div>
          <p className="dash-subtitle">
            {firstName ? `Welcome, ${firstName}!` : 'Welcome back!'} Let’s keep the streak alive.
          </p>
        </div>
        <div className="dash-hero-right">
          <button className="submit gray" onClick={() => navigate('/credits')}>Credits</button>
          {isAdmin && (
            <button className="submit gray" onClick={() => navigate('/dashboard/admin')}>
              Admin
            </button>
          )}
          <button className="submit gray" onClick={fetchDashboard}>Refresh</button>
          <button className="submit gray" onClick={handleResetToday}>Reset Today</button>
          <button className="submit" onClick={handleLogout}>Logout</button>
        </div>
      </header>

      {/* Stats Grid */}
      <section className="stats-grid">
        {loading ? (
          Array.from({ length: 5 }).map((_, i) => (
            <div className="stats-card skeleton" key={i}>
              <div className="sk-line sk-1"></div>
              <div className="sk-line sk-2"></div>
            </div>
          ))
        ) : cards.length === 0 ? (
          <div className="empty-card">
            No data yet — log a workout or food entry to see your insights.
          </div>
        ) : (
          cards.map(({ label, value, route }) => (
            <Link to={route} key={label} className="stats-card">
              <div className="stats-card-label">{label}</div>
              <div className="stats-card-value">{value}</div>
              <div className="stats-card-cta">Open →</div>
            </Link>
          ))
        )}
      </section>

      {/* Today’s Log */}
      <div className="log-panel">
        <h3 className="log-title">Today’s Log</h3>
        <ul className="log-list">
          {recent.map((e,i) => (
            <li key={i} className={`log-entry ${e.type}`}>
              <span className="log-icon">
                {e.type === 'food' ? '+' : e.type === 'activity' ? '−' : '💤'}
              </span>
              <span className="log-value">
                {e.type === 'sleep' ? e.label : `${Math.abs(e.calories)} kcal`}
              </span>
              <span className="log-label">{e.label}</span>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
