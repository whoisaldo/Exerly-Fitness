// frontend/src/Components/Admin/Admin.jsx
import { useNavigate } from 'react-router-dom';
import React, { useEffect, useState, useMemo } from 'react';
import '../Dashboard/Dashboard.css';
import '../Dashboard/Calories.css';

const BASE_URL = process.env.REACT_APP_API_URL;

// tiny JWT decode (no deps)
function decodeJWT(token) {
  try {
    const base64 = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    return JSON.parse(atob(base64));
  } catch {
    return null;
  }
}

export default function Admin() {
  const navigate = useNavigate();
  const [users, setUsers] = useState([]);
  const [email, setEmail] = useState('');
  const [entries, setEntries] = useState({ activities: [], food: [], sleep: [] });
  const [loading, setLoading] = useState(true);

  const token = localStorage.getItem('token') || '';
  const me = useMemo(() => decodeJWT(token) || {}, [token]);

  // Load users list (admin-only)
  useEffect(() => {
    if (!token) { navigate('/'); return; }
    if (!me?.is_admin) { navigate('/dashboard'); return; }

    fetch(`${BASE_URL}/api/admin/users`, {
      headers: { Authorization: 'Bearer ' + token }
    })
      .then(r => {
        if (r.status === 401) { navigate('/'); return Promise.reject('Unauthorized'); }
        if (r.status === 403) { navigate('/dashboard'); return Promise.reject('Not admin'); }
        return r.json();
      })
      .then(list => {
        setUsers(list || []);
        setEmail(list?.[0]?.email || '');
      })
      .catch(console.error);
  }, [navigate, token, me]);

  // Load selected user's entries
  useEffect(() => {
    if (!email) { setEntries({ activities: [], food: [], sleep: [] }); return; }
    setLoading(true);
    fetch(`${BASE_URL}/api/admin/user/${encodeURIComponent(email)}/entries`, {
      headers: { Authorization: 'Bearer ' + token }
    })
      .then(r => r.json())
      .then(data => setEntries({
        activities: data.activities || [],
        food: data.food || [],
        sleep: data.sleep || []
      }))
      .finally(() => setLoading(false));
  }, [email, token]);

  const totals = useMemo(() => {
    const burned = entries.activities.reduce((s, a) => s + Number(a.calories || 0), 0);
    const consumed = entries.food.reduce((s, f) => s + Number(f.calories || 0), 0);
    const sleepHrs = entries.sleep.reduce((s, sl) => s + Number(sl.hours || 0), 0);
    return { workouts: entries.activities.length, burned, consumed, sleepHrs };
  }, [entries]);

  const resetTodayForUser = async () => {
    if (!email) return;
    const ok = window.confirm(`Reset today's logs for ${email}? This cannot be undone.`);
    if (!ok) return;

    const res = await fetch(`${BASE_URL}/api/admin/user/${encodeURIComponent(email)}/reset-today`, {
      method: 'POST',
      headers: { Authorization: 'Bearer ' + token }
    });

    if (res.ok) {
      const data = await fetch(`${BASE_URL}/api/admin/user/${encodeURIComponent(email)}/entries`, {
        headers: { Authorization: 'Bearer ' + token }
      }).then(r => r.json());
      setEntries({
        activities: data.activities || [],
        food: data.food || [],
        sleep: data.sleep || []
      });
    } else {
      alert('Reset failed.');
    }
  };

  return (
    <div className="container dashboard-container">
      {/* Header */}
      <header className="dash-hero">
        <div className="dash-hero-left">
          <div className="dash-badge">Exerly</div>
          <h1 className="dash-title">Admin Console</h1>
          <p className="dash-subtitle">Manage users, view logs, and reset today’s data.</p>
        </div>
        <div className="dash-hero-right">
          <button className="btn-ghost" onClick={() => navigate('/dashboard')}>Back</button>
        </div>
      </header>

      {/* Toolbar */}
      <div className="admin-toolbar">
        <label className="admin-label">User</label>
        <select className="ui-select" value={email} onChange={e => setEmail(e.target.value)}>
          {users.map(u => (
            <option key={u.email} value={u.email}>
              {(u.name || u.email)} • {u.email}
            </option>
          ))}
        </select>
        <button className="btn-danger" onClick={resetTodayForUser}>Reset Today for User</button>
      </div>

      {/* KPIs */}
      <section className="stats-grid">
        <div className="stats-card">
          <div className="stats-card-top"><span className="stats-chip">Total Workouts</span></div>
          <div className="stats-card-value">{totals.workouts}</div>
          <div className="stats-card-cta">Open →</div>
        </div>
        <div className="stats-card">
          <div className="stats-card-top"><span className="stats-chip">Calories Burned</span></div>
          <div className="stats-card-value">{totals.burned} kcal</div>
          <div className="stats-card-cta">Open →</div>
        </div>
        <div className="stats-card">
          <div className="stats-card-top"><span className="stats-chip">Calories Consumed</span></div>
          <div className="stats-card-value">{totals.consumed} kcal</div>
          <div className="stats-card-cta">Open →</div>
        </div>
        <div className="stats-card">
          <div className="stats-card-top"><span className="stats-chip">Sleep (hrs)</span></div>
          <div className="stats-card-value">{totals.sleepHrs}h</div>
          <div className="stats-card-cta">Open →</div>
        </div>
      </section>

      {/* Lists */}
      <section className="section-card">
        <h3 className="section-title">Activities</h3>
        {loading ? <div className="skeleton sk-line" /> : (
          entries.activities.length === 0 ? <p className="muted">No activities.</p> :
            <ul className="log-list">
              {entries.activities.map(a => (
                <li key={`a-${a.id}`}>
                  <span>{a.activity} • {a.duration_min} min</span>
                  <span className="mono">{a.calories} kcal</span>
                </li>
              ))}
            </ul>
        )}
      </section>

      <section className="section-card">
        <h3 className="section-title">Food</h3>
        {loading ? <div className="skeleton sk-line" /> : (
          entries.food.length === 0 ? <p className="muted">No food logs.</p> :
            <ul className="log-list">
              {entries.food.map(f => (
                <li key={`f-${f.id}`}>
                  <span>{f.name}</span>
                  <span className="mono">{f.calories} kcal</span>
                </li>
              ))}
            </ul>
        )}
      </section>

      <section className="section-card">
        <h3 className="section-title">Sleep</h3>
        {loading ? <div className="skeleton sk-line" /> : (
          entries.sleep.length === 0 ? <p className="muted">No sleep logs.</p> :
            <ul className="log-list">
              {entries.sleep.map(s => (
                <li key={`s-${s.id}`}>
                  <span>{s.hours}h • {s.quality}</span>
                  <span className="mono">{new Date(s.entry_date).toISOString().slice(0, 10)}</span>
                </li>
              ))}
            </ul>
        )}
      </section>
    </div>
  );
}