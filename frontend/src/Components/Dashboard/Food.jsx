// frontend/src/Components/Dashboard/Food.jsx
import React, { useEffect, useState } from 'react';
import { useNavigate }                from 'react-router-dom';
import '../LoginSignup/LoginSignup.css';
import './Dashboard.css';
import './Calories.css';  // reuse form styles

export default function Food() {
  const [entries, setEntries] = useState([]);
  const [form, setForm]       = useState({
    name: '', calories: '', protein: '', sugar: ''
  });
  const navigate = useNavigate();

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) return navigate('/');
    fetch('http://localhost:3001/api/food', {
      headers: { Authorization: 'Bearer ' + token }
    })
      .then(r => r.json())
      .then(data => Array.isArray(data) ? setEntries(data) : setEntries([]))
      .catch(() => setEntries([]));
  }, [navigate]);

  const handleChange = e =>
    setForm({ ...form, [e.target.name]: e.target.value });

  const handleSubmit = async e => {
    e.preventDefault();
    const token = localStorage.getItem('token');
    if (!token) return navigate('/');

    const res = await fetch('http://localhost:3001/api/food', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization:  'Bearer ' + token
      },
      body: JSON.stringify(form)
    });

    if (res.ok) {
      const entry = await res.json();
      setEntries([entry, ...entries]);
      setForm({ name:'', calories:'', protein:'', sugar:'' });
    } else if (res.status===401) {
      navigate('/');
    } else {
      console.error('Save failed:', await res.text());
    }
  };

  return (
    <div className="container">
      <div className="header">
        <button className="submit" onClick={()=>navigate('/dashboard')}>
          Back
        </button>
        <div className="text">Food Tracker</div>
        <div className="underline"></div>
      </div>

      <form onSubmit={handleSubmit} className="calorie-form">
        <input
          name="name"
          placeholder="Food Name"
          value={form.name}
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
        <button type="submit">Log Food</button>
      </form>

      <div className="stats-grid">
        {!Array.isArray(entries) ? (
          <p>Loading…</p>
        ) : entries.length===0 ? (
          <p>No food logged yet.</p>
        ) : (
          entries.map(e => (
            <div key={e.id} className="stats-card">
              <div className="stats-card-label">{e.name}</div>
              <div className="stats-card-value">{e.calories} kcal</div>
              <div className="stats-card-label">
                {e.protein}g P • {e.sugar}g S
              </div>
              <div className="stats-card-label">
                {e.entry_date}
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
