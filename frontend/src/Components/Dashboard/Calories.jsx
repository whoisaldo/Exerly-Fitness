// frontend/src/Components/Dashboard/Calories.jsx
import React, { useEffect, useState } from 'react';
import { useNavigate }                from 'react-router-dom';
import '../LoginSignup/LoginSignup.css';
import './Dashboard.css';
import './Calories.css';
const BASE_URL = process.env.REACT_APP_API_URL;
export default function Calories() {
  const [entries, setEntries] = useState([]);
  const [form, setForm]       = useState({
    activity:     '',
    duration_min: '',
    calories:     '',
    protein:      '',
    sugar:        ''
  });
  const navigate = useNavigate();

  // Load existing entries
  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) return navigate('/');

    fetch(`${BASE_URL}/api/calories`, {
      headers: { Authorization: 'Bearer ' + token }
    })
      .then(res => {
        if (res.status === 401) {
          navigate('/'); throw new Error('Unauthorized');
        }
        if (!res.ok) throw new Error(`Fetch failed: ${res.status}`);
        return res.json();
      })
      .then(data => {
        if (Array.isArray(data)) setEntries(data);
        else setEntries([]);
      })
      .catch(() => setEntries([]));
  }, [navigate]);

  // Update form state
  const handleChange = e =>
    setForm({ ...form, [e.target.name]: e.target.value });

  // Submit new macro entry
  const handleSubmit = async e => {
    e.preventDefault();
    const token = localStorage.getItem('token');
    if (!token) return navigate('/');

    const res = await fetch(`${BASE_URL}/api/calories`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization:  'Bearer ' + token
      },
      body: JSON.stringify({
        activity:     form.activity,
        duration_min: form.duration_min,
        calories:     form.calories,
        protein:      form.protein,
        sugar:        form.sugar
      })
    });

    if (res.ok) {
      const entry = await res.json();
      setEntries([entry, ...entries]);
      setForm({ activity:'', duration_min:'', calories:'', protein:'', sugar:'' });
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
        <div className="text">Nutrition Tracker</div>
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
          placeholder="Calories"
          value={form.calories}
          onChange={handleChange}
          required
        />
        <input
          name="protein"
          type="number"
          placeholder="Protein (g)"
          value={form.protein}
          onChange={handleChange}
          required
        />
        <input
          name="sugar"
          type="number"
          placeholder="Sugar (g)"
          value={form.sugar}
          onChange={handleChange}
          required
        />
        <button type="submit">Log</button>
      </form>

      <div className="stats-grid">
        {!Array.isArray(entries) ? (
          <p>Loading…</p>
        ) : entries.length === 0 ? (
          <p>No entries yet.</p>
        ) : (
          entries.map(e => (
            <div key={e.id} className="stats-card">
              <div className="stats-card-label">{e.activity}</div>
              <div className="stats-card-value">{e.calories} kcal</div>
              <div className="stats-card-label">
                {e.protein}g Protein, {e.sugar}g Sugar
              </div>
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
