// frontend/src/Components/Dashboard/Dashboard.jsx
import React, { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import '../LoginSignup/LoginSignup.css';
import './Dashboard.css';

const BASE_URL = process.env.REACT_APP_API_URL;

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
  const firstName = useMemo(() => {
    if (!token) return '';
    const payload = decodeJWT(token);
    const name = payload?.name || '';
    return name.trim().split(' ')[0] || '';
  }, [token]);

  useEffect(() => {
    if (!token) return navigate('/');

    fetch(`${BASE_URL}/api/dashboard-data`, {
      headers: { Authorization: 'Bearer ' + token }
    })
      .then(res => {
        if (res.status === 401) { navigate('/'); throw new Error('Unauthorized'); }
        return res.json();
      })
      .then(data => {
        // Build stats cards array
        setStats([
          { label:'Total Workouts',    value: data.workoutCount,            route:'/dashboard/activities' },
          { label:'Calories Burned',   value:`${data.totalBurned} kcal`,    route:'/dashboard/activities' },
          { label:'Calories Consumed', value:`${data.totalConsumed} kcal`, route:'/dashboard/food' },
          { label:'Sleep (hrs)',       value:`${data.totalSleepHours}h`,     route:'/dashboard/hours' },
          { label:'Maintenance',       value:`${data.maintenance} kcal`,     route:'/dashboard/profile' },
          { label:'Net',               value:`${data.net >= 0 ? '+' : ''}${data.net} kcal`, route:'/dashboard' },
        ]);
        // Save recent log entries
        setRecent(data.recent || []);
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [navigate, token]);

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
        ) : stats.length === 0 ? (
          <div className="empty-card">
            No data yet — log a workout or food entry to see your insights.
          </div>
        ) : (
          stats.map(({ label, value, route }) => (
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