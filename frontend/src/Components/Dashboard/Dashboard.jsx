// frontend/src/Components/Dashboard/Dashboard.jsx
import React, { useEffect, useMemo, useState, useCallback } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import './Dashboard.css';
import API_CONFIG from '../../config';

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
    (process.env.REACT_APP_ADMIN_EMAILS || '')
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

  return (
    <div className="dashboard-page">
      {/* Enhanced Header */}
      <header className="dashboard-header">
        <div className="header-left">
          <div className="welcome-section">
            <h1 className="welcome-title">Welcome back, {firstName || 'Fitness Warrior'}! 💪</h1>
            <p className="welcome-subtitle">Let's crush today's fitness goals together</p>
          </div>
        </div>
        
        <div className="header-right">
          <div className="header-actions">
            <button 
              className={`action-btn refresh-btn ${refreshing ? 'loading' : ''}`}
              onClick={handleRefresh}
              disabled={refreshing}
              title="Refresh Data"
            >
              {refreshing ? <div className="spinner"></div> : '🔄'}
            </button>
            
            <button 
              className="action-btn credits-btn"
              onClick={() => navigate('/credits')}
              title="Credits"
            >
              Credits
            </button>
            
            {isAdmin && (
              <button 
                className="action-btn admin-btn"
                onClick={() => navigate('/dashboard/admin')}
                title="Admin Panel"
              >
                👑 Admin
              </button>
            )}
            
            <button 
              className="action-btn reset-btn"
              onClick={handleResetToday}
              disabled={refreshing}
              title="Reset Today's Data"
            >
              Reset Today
            </button>
            
            <button 
              className="action-btn logout-btn"
              onClick={handleLogout}
              title="Logout"
            >
              Logout
            </button>
          </div>
        </div>
      </header>

      {/* Error Message */}
      {error && (
        <div className="error-banner">
          <span className="error-text">{error}</span>
          <button className="error-close" onClick={() => setError('')}>×</button>
        </div>
      )}

      {/* Enhanced Stats Grid */}
      <section className="stats-section">
        <h2 className="section-title">Today's Overview</h2>
        <div className="stats-grid">
          {loading ? (
            Array.from({ length: 7 }).map((_, i) => (
              <div className="stats-card skeleton" key={i}>
                <div className="skeleton-icon"></div>
                <div className="skeleton-content">
                  <div className="skeleton-line skeleton-title"></div>
                  <div className="skeleton-line skeleton-value"></div>
                </div>
              </div>
            ))
          ) : cards.length === 0 ? (
            <div className="empty-state">
              <div className="empty-icon">📊</div>
              <h3 className="empty-title">No data yet</h3>
              <p className="empty-description">
                Start logging your workouts, food, and sleep to see your insights here.
              </p>
              <div className="empty-actions">
                <Link to="/dashboard/activities" className="empty-btn">Log Workout</Link>
                <Link to="/dashboard/food" className="empty-btn">Log Food</Link>
                <Link to="/dashboard/sleep" className="empty-btn">Log Sleep</Link>
                <Link to="/dashboard/goals" className="empty-btn">Set Goals</Link>
                <Link to="/dashboard/ai-coach" className="empty-btn ai-coach-btn">💪 AI Coach</Link>
              </div>
            </div>
          ) : (
            cards.map(({ label, value, route, icon, color }) => (
              <Link to={route} key={label} className={`stats-card ${color}`}>
                <div className="card-icon">{icon}</div>
                <div className="card-content">
                  <h3 className="card-label">{label}</h3>
                  <div className="card-value">{value}</div>
                </div>
                <div className="card-arrow">→</div>
              </Link>
            ))
          )}
        </div>
      </section>

      {/* Goals Progress Section */}
      {goalsProgress && Object.keys(goalsProgress).length > 0 && (
        <section className="goals-progress-section" style={{ margin: '30px 0', padding: '25px', background: 'white', borderRadius: '15px', boxShadow: '0 4px 12px rgba(0,0,0,0.08)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
            <h2 className="section-title" style={{ margin: 0 }}>🎯 Goals Progress</h2>
            <Link to="/dashboard/goals" style={{ color: '#3b82f6', textDecoration: 'none', fontSize: '14px', fontWeight: '500' }}>
              Manage Goals →
            </Link>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '20px' }}>
            {goalsProgress.weeklyWorkouts && (
              <div style={{ padding: '15px', background: '#f9fafb', borderRadius: '10px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
                  <span style={{ fontSize: '14px', fontWeight: '500', color: '#6b7280' }}>💪 Weekly Workouts</span>
                  <span style={{ fontSize: '14px', fontWeight: 'bold', color: '#1f2937' }}>
                    {goalsProgress.weeklyWorkouts.current} / {goalsProgress.weeklyWorkouts.goal}
                  </span>
                </div>
                <div style={{ width: '100%', height: '10px', background: '#e5e7eb', borderRadius: '5px', overflow: 'hidden' }}>
                  <div style={{ 
                    width: `${goalsProgress.weeklyWorkouts.percentage}%`, 
                    height: '100%', 
                    background: goalsProgress.weeklyWorkouts.percentage >= 100 ? '#10b981' : '#3b82f6',
                    transition: 'width 0.3s ease'
                  }}></div>
                </div>
                <div style={{ marginTop: '5px', fontSize: '12px', color: '#6b7280', textAlign: 'right' }}>
                  {goalsProgress.weeklyWorkouts.percentage.toFixed(0)}% Complete
                </div>
              </div>
            )}
            {goalsProgress.dailyCalories && (
              <div style={{ padding: '15px', background: '#f9fafb', borderRadius: '10px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
                  <span style={{ fontSize: '14px', fontWeight: '500', color: '#6b7280' }}>🔥 Daily Calories</span>
                  <span style={{ fontSize: '14px', fontWeight: 'bold', color: '#1f2937' }}>
                    {goalsProgress.dailyCalories.current} / {goalsProgress.dailyCalories.goal}
                  </span>
                </div>
                <div style={{ width: '100%', height: '10px', background: '#e5e7eb', borderRadius: '5px', overflow: 'hidden' }}>
                  <div style={{ 
                    width: `${goalsProgress.dailyCalories.percentage}%`, 
                    height: '100%', 
                    background: goalsProgress.dailyCalories.percentage >= 100 ? '#10b981' : '#f59e0b',
                    transition: 'width 0.3s ease'
                  }}></div>
                </div>
                <div style={{ marginTop: '5px', fontSize: '12px', color: '#6b7280', textAlign: 'right' }}>
                  {goalsProgress.dailyCalories.percentage.toFixed(0)}% Complete
                </div>
              </div>
            )}
            {goalsProgress.sleepHours && (
              <div style={{ padding: '15px', background: '#f9fafb', borderRadius: '10px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
                  <span style={{ fontSize: '14px', fontWeight: '500', color: '#6b7280' }}>😴 Sleep Hours</span>
                  <span style={{ fontSize: '14px', fontWeight: 'bold', color: '#1f2937' }}>
                    {goalsProgress.sleepHours.current}h / {goalsProgress.sleepHours.goal}h
                  </span>
                </div>
                <div style={{ width: '100%', height: '10px', background: '#e5e7eb', borderRadius: '5px', overflow: 'hidden' }}>
                  <div style={{ 
                    width: `${goalsProgress.sleepHours.percentage}%`, 
                    height: '100%', 
                    background: goalsProgress.sleepHours.percentage >= 100 ? '#10b981' : '#8b5cf6',
                    transition: 'width 0.3s ease'
                  }}></div>
                </div>
                <div style={{ marginTop: '5px', fontSize: '12px', color: '#6b7280', textAlign: 'right' }}>
                  {goalsProgress.sleepHours.percentage.toFixed(0)}% Complete
                </div>
              </div>
            )}
          </div>
        </section>
      )}

      {/* Enhanced Today's Log */}
      <section className="log-section">
        <div className="section-header">
          <h2 className="section-title">Today's Activity Log</h2>
          <span className="log-count">{recent.length} entries</span>
        </div>
        
        <div className="log-container">
          {recent.length === 0 ? (
            <div className="empty-log">
              <div className="empty-log-icon">📝</div>
              <p className="empty-log-text">No activities logged today</p>
              <p className="empty-log-subtext">Start your day by logging your first activity!</p>
              <div className="empty-actions">
                <Link to="/dashboard/activities" className="empty-btn">Log Workout</Link>
                <Link to="/dashboard/food" className="empty-btn">Log Food</Link>
                <Link to="/dashboard/sleep" className="empty-btn">Log Sleep</Link>
                <Link to="/dashboard/goals" className="empty-btn">Set Goals</Link>
                <Link to="/dashboard/ai-coach" className="empty-btn ai-coach-btn">💪 AI Coach</Link>
              </div>
            </div>
          ) : (
            <div className="log-timeline">
              {recent.map((entry, index) => (
                <div key={`${entry.type}-${index}`} className={`log-entry ${entry.type}`}>
                  <div className="entry-icon">{entry.icon}</div>
                  <div className="entry-content">
                    <div className="entry-label">{entry.label}</div>
                    <div className="entry-meta">
                      {entry.type === 'sleep' ? (
                        <span className="entry-time">{entry.label}</span>
                      ) : (
                        <span className={`entry-calories ${entry.calories >= 0 ? 'positive' : 'negative'}`}>
                          {entry.calories >= 0 ? '+' : ''}{entry.calories} calories
                        </span>
                      )}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </section>
    </div>
  );
}
