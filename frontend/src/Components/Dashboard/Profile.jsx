// frontend/src/Components/Profile/Profile.jsx
import React, { useEffect, useState } from 'react';
import { useNavigate }               from 'react-router-dom';
import '../LoginSignup/LoginSignup.css';
import './Dashboard.css';
import './Calories.css';

const BASE_URL = process.env.REACT_APP_API_URL;

export default function Profile() {
  const navigate = useNavigate();
  const [form, setForm] = useState({
    age: '',
    sex: 'male',
    height_cm: '',
    weight_kg: '',
    activity_level: 'moderate',
  });
  const [loading, setLoading] = useState(true);

  // Load existing profile
  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) return navigate('/');
    fetch(`${BASE_URL}/api/profile`, {
      headers: { Authorization: 'Bearer ' + token },
    })
      .then(res => {
        if (res.status === 401) {
          navigate('/');
          throw new Error('Unauthorized');
        }
        return res.json();
      })
      .then(data => {
        if (data && Object.keys(data).length > 0) {
          setForm({
            age: data.age || '',
            sex: data.sex || 'male',
            height_cm: data.height_cm || '',
            weight_kg: data.weight_kg || '',
            activity_level: data.activity_level || 'moderate',
          });
        }
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [navigate]);

  const handleChange = e => {
    const { name, value } = e.target;
    setForm(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async e => {
    e.preventDefault();
    const token = localStorage.getItem('token');
    if (!token) return navigate('/');
    try {
      const res = await fetch(`${BASE_URL}/api/profile`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer ' + token,
        },
        body: JSON.stringify(form),
      });
      if (res.ok) {
        navigate('/dashboard');
      } else {
        console.error('Profile save failed:', await res.text());
      }
    } catch (err) {
      console.error('Error saving profile:', err);
    }
  };

  if (loading) {
    return (
      <div className="container">
        <p className="text">Loading profile…</p>
      </div>
    );
  }

  return (
    <div className="container">
      {/* Header */}
      <div className="header">
        <button className="submit" onClick={() => navigate('/dashboard')}>
          ← Back
        </button>
        <div className="text">Your Profile</div>
        <div className="underline" />
      </div>

      {/* Profile Form */}
      <form onSubmit={handleSubmit} className="calorie-form">
        <div className="input">
          <input
            name="age"
            type="number"
            placeholder="Age"
            value={form.age}
            onChange={handleChange}
            required
          />
        </div>
        <div className="input">
          <select name="sex" value={form.sex} onChange={handleChange}>
            <option value="male">Male</option>
            <option value="female">Female</option>
          </select>
        </div>
        <div className="input">
          <input
            name="height_cm"
            type="number"
            placeholder="Height (cm)"
            value={form.height_cm}
            onChange={handleChange}
            required
          />
        </div>
        <div className="input">
          <input
            name="weight_kg"
            type="number"
            placeholder="Weight (kg)"
            value={form.weight_kg}
            onChange={handleChange}
            required
          />
        </div>
        <div className="input">
          <select
            name="activity_level"
            value={form.activity_level}
            onChange={handleChange}
          >
            <option value="sedentary">Sedentary</option>
            <option value="light">Light</option>
            <option value="moderate">Moderate</option>
            <option value="active">Active</option>
            <option value="very active">Very Active</option>
          </select>
        </div>

        {/* Save Button */}
        <div className="submit-container">
          <button type="submit" className="submit">
            Save Profile
          </button>
        </div>
      </form>
    </div>
  );
}
