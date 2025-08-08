import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import '../LoginSignup/LoginSignup.css';
import './Dashboard.css';
import './Calories.css';  // reuse styles
const BASE_URL = 'https://powerful-citadel-83317-b198c7aed44f.herokuapp.com';

export default function Sleep() {
  const [entries, setEntries] = useState([]);
  const [form, setForm] = useState({
    hours: '',
    quality: ''
  });
  const navigate = useNavigate();

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) return navigate('/');
    fetch(`${BASE_URL}/api/sleep`, {
      headers: { Authorization: 'Bearer ' + token }
    })
      .then(res => {
        if (res.status === 401) {
          navigate('/');
          throw new Error('Unauthorized');
        }
        return res.json();
      })
      .then(data => Array.isArray(data) ? setEntries(data) : setEntries([]))
      .catch(() => setEntries([]));
  }, [navigate]);

  const handleChange = e =>
    setForm({ ...form, [e.target.name]: e.target.value });

  const handleSubmit = async e => {
    e.preventDefault();
    const token = localStorage.getItem('token');
    if (!token) return navigate('/');

    const res = await fetch(`${BASE_URL}/api/sleep`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer ' + token
      },
      body: JSON.stringify({
        hours: form.hours,
        quality: form.quality
      })
    });

    if (res.ok) {
      const entry = await res.json();
      setEntries([entry, ...entries]);
      setForm({ hours: '', quality: '' });
    } else if (res.status === 401) {
      navigate('/');
    } else {
      const errorText = await res.text();
      console.error('Save failed:', errorText);
      alert('Error: ' + errorText);
    }
  };

  return (
    <div className="container">
      <div className="header">
        <button className="submit" onClick={() => navigate('/dashboard')}>
          Back
        </button>
        <div className="text">Sleep Tracker</div>
        <div className="underline"></div>
      </div>

      <form onSubmit={handleSubmit} className="calorie-form">
        <input
          name="hours"
          type="number"
          placeholder="Hours Slept"
          value={form.hours}
          onChange={handleChange}
          required
        />
        <input
          name="quality"
          placeholder="Sleep Quality (e.g. Good, Fair)"
          value={form.quality}
          onChange={handleChange}
          required
        />
        <button type="submit">Log Sleep</button>
      </form>

      <div className="stats-grid">
        {!Array.isArray(entries) ? (
          <p>Loading…</p>
        ) : entries.length === 0 ? (
          <p>No sleep data logged yet.</p>
        ) : (
          entries.map(e => (
            <div key={e.id} className="stats-card">
              <div className="stats-card-label">{e.hours} hours</div>
              <div className="stats-card-value">{e.quality}</div>
              <div className="stats-card-label">{e.entry_date}</div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
