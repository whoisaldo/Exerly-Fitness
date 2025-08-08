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
      .then(data => setStats(Array.isArray(data) ? data : []))
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [navigate, token]);

  const handleLogout = () => {
    localStorage.removeItem('token');
    navigate('/');
  };

  return (
    <div className="container dashboard-container">
      {/* Hero Header */}
      <header className="dash-hero">
        <div className="dash-hero-left">
          <div className="dash-badge">Exerly</div>
          <h1 className="dash-title">Dashboard</h1>
          <p className="dash-subtitle">
            {firstName ? `Welcome, ${firstName}!` : 'Welcome back!'} Let’s keep the streak alive.
          </p>
        </div>
        <div className="dash-hero-right">
          <button className="btn-ghost" onClick={() => navigate('/credits')}>Credits</button>
          <button className="btn-primary" onClick={handleLogout}>Logout</button>
        </div>
      </header>

      {/* Stats Grid */}
      <section className="stats-grid">
        {loading ? (
          // Skeletons
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
              <div className="stats-card-top">
                <span className="stats-chip">{label}</span>
              </div>
              <div className="stats-card-value">{value}</div>
              <div className="stats-card-cta">Open →</div>
            </Link>
          ))
        )}
      </section>
    </div>
  );
}