// frontend/src/Components/Dashboard/Activities.jsx
import React, { useEffect, useState } from 'react';
import { useNavigate }                from 'react-router-dom';
import '../LoginSignup/LoginSignup.css';
import './Dashboard.css';
import './Calories.css';  // re-use the form styles

export default function Activities() {
  const [entries, setEntries] = useState([]);
  const [form, setForm]       = useState({
    activity:     '',
    duration_min: '',
    calories:     ''
  });
  const navigate = useNavigate();

  // Load existing activities
  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) return navigate('/');

    fetch('http://localhost:3001/api/activities', {
      headers: { Authorization: 'Bearer ' + token }
    })
      .then(r => {
        if (r.status === 401) { navigate('/'); throw new Error('Unauthorized'); }
        if (!r.ok) throw new Error(`Fetch failed: ${r.status}`);
        return r.json();
      })
      .then(data => Array.isArray(data) ? setEntries(data) : setEntries([]))
      .catch(() => setEntries([]));
  }, [navigate]);

  // Handle form fields
  const handleChange = e =>
    setForm({ ...form, [e.target.name]: e.target.value });

  // Submit a new activity
  const handleSubmit = async e => {
    e.preventDefault();
    const token = localStorage.getItem('token');
    if (!token) return navigate('/');

    const res = await fetch('http://localhost:3001/api/activities', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization:  'Bearer ' + token
      },
      body: JSON.stringify({
        activity:     form.activity,
        duration_min: form.duration_min,
        calories:     form.calories
      })
    });

    if (res.ok) {
      const entry = await res.json();
      setEntries([entry, ...entries]);
      setForm({ activity:'', duration_min:'', calories:'' });
    } else if (res.status === 401) {
      navigate('/');
    } else {
      console.error('Save failed:', await res.text());
    }
  };

  return (
    <div className="container">
      <div className="header">
        <button className="submit" onClick={() => navigate('/dashboard')}>
          Back
        </button>
        <div className="text">Activity Tracker</div>
        <div className="underline"></div>
      </div>

      <form onSubmit={handleSubmit} className="calorie-form">
        <input
          name="activity"
          placeholder="Activity (e.g. Running)"
          value={form.activity}
          onChange={handleChange}
          required
        />
        <input
          name="duration_min"
          type="number"
          placeholder="Duration (min)"
          value={form.duration_min}
          onChange={handleChange}
          required
        />
        <input
          name="calories"
          type="number"
          placeholder="Calories Burned"
          value={form.calories}
          onChange={handleChange}
          required
        />
        <button type="submit">Log Activity</button>
      </form>

      <div className="stats-grid">
        {!Array.isArray(entries) ? (
          <p>Loading…</p>
        ) : entries.length === 0 ? (
          <p>No activities logged yet.</p>
        ) : (
          entries.map(e => (
            <div key={e.id} className="stats-card">
              <div className="stats-card-label">{e.activity}</div>
              <div className="stats-card-value">{e.calories} kcal</div>
              <div className="stats-card-label">
                {e.duration_min} min on {e.entry_date}
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
