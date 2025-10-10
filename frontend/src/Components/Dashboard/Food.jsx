// frontend/src/Components/Dashboard/Food.jsx
import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import './Food.css';
import API_CONFIG from '../../config';

const BASE_URL = API_CONFIG.BASE_URL;

export default function Food() {
  const [entries, setEntries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({
    name: '',
    calories: '',
    protein: '',
    sugar: '',
    carbs: '',
    fat: '',
    mealType: 'Snack'
  });
  const navigate = useNavigate();

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) return navigate('/');
    
    fetchFoodData();
  }, [navigate]);

  const fetchFoodData = async () => {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${BASE_URL}/api/food`, {
        headers: { Authorization: 'Bearer ' + token }
      });
      
      if (res.status === 401) {
        navigate('/');
        return;
      }
      
      const data = await res.json();
      setEntries(Array.isArray(data) ? data : []);
    } catch (error) {
      console.error('Error fetching food data:', error);
      setEntries([]);
    } finally {
      setLoading(false);
    }
  };

  const handleChange = e => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const handleSubmit = async e => {
    e.preventDefault();
    setSaving(true);
    
    try {
      const token = localStorage.getItem('token');
      if (!token) return navigate('/');

      const res = await fetch(`${BASE_URL}/api/food`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer ' + token
        },
        body: JSON.stringify(form)
      });

      if (res.ok) {
        const entry = await res.json();
        setEntries([entry, ...entries]);
        setForm({ 
          name: '', 
          calories: '', 
          protein: '', 
          sugar: '', 
          carbs: '', 
          fat: '', 
          mealType: 'Snack' 
        });
        alert('✅ Food logged successfully!');
      } else if (res.status === 401) {
        navigate('/');
      } else {
        const errorText = await res.text();
        console.error('Save failed:', errorText);
        alert('Error: ' + errorText);
      }
    } catch (error) {
      console.error('Error saving food data:', error);
      alert('Error saving food data');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure you want to delete this food entry?')) return;
    
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${BASE_URL}/api/food/${id}`, {
        method: 'DELETE',
        headers: { Authorization: 'Bearer ' + token }
      });

      if (res.ok) {
        setEntries(entries.filter(entry => entry.id !== id));
        alert('✅ Food entry deleted successfully!');
      } else {
        alert('Error deleting food entry');
      }
    } catch (error) {
      console.error('Error deleting food:', error);
      alert('Error deleting food entry');
    }
  };

  const calculateNutritionStats = () => {
    if (entries.length === 0) return null;
    
    const totalCalories = entries.reduce((sum, entry) => sum + parseFloat(entry.calories || 0), 0);
    const totalProtein = entries.reduce((sum, entry) => sum + parseFloat(entry.protein || 0), 0);
    const totalSugar = entries.reduce((sum, entry) => sum + parseFloat(entry.sugar || 0), 0);
    const totalCarbs = entries.reduce((sum, entry) => sum + parseFloat(entry.carbs || 0), 0);
    const totalFat = entries.reduce((sum, entry) => sum + parseFloat(entry.fat || 0), 0);
    
    return {
      totalCalories: totalCalories.toFixed(0),
      totalProtein: totalProtein.toFixed(1),
      totalSugar: totalSugar.toFixed(1),
      totalCarbs: totalCarbs.toFixed(1),
      totalFat: totalFat.toFixed(1),
      avgCalories: (totalCalories / entries.length).toFixed(0),
      totalEntries: entries.length
    };
  };

  const stats = calculateNutritionStats();

  const getMealTypeIcon = (mealType) => {
    switch (mealType?.toLowerCase()) {
      case 'breakfast': return '🌅';
      case 'lunch': return '🌞';
      case 'dinner': return '🌙';
      case 'snack': return '🍎';
      default: return '🍽️';
    }
  };

  const getMealTypeColor = (mealType) => {
    switch (mealType?.toLowerCase()) {
      case 'breakfast': return '#f59e0b';
      case 'lunch': return '#10b981';
      case 'dinner': return '#8b5cf6';
      case 'snack': return '#ec4899';
      default: return '#6b7280';
    }
  };

  return (
    <div className="food-page">
      {/* Header */}
      <div className="food-header">
        <button className="back-btn" onClick={() => navigate('/dashboard')}>
          Back to Dashboard
        </button>
        <div className="header-content">
          <h1 className="food-title">Food Tracker</h1>
          <p className="food-subtitle">Track your nutrition and maintain a healthy diet</p>
        </div>
      </div>

      {/* Main Content */}
      <div className="food-content">
        {/* Quick Stats */}
        {stats && (
          <div className="stats-section">
            <h2 className="section-title">Today's Nutrition</h2>
            <div className="stats-grid">
              <div className="stat-card">
                <div className="stat-icon">🔥</div>
                <div className="stat-value">{stats.totalCalories}</div>
                <div className="stat-label">Total Calories</div>
              </div>
              <div className="stat-card">
                <div className="stat-icon">💪</div>
                <div className="stat-value">{stats.totalProtein}g</div>
                <div className="stat-label">Total Protein</div>
              </div>
              <div className="stat-card">
                <div className="stat-icon">🍞</div>
                <div className="stat-value">{stats.totalCarbs}g</div>
                <div className="stat-label">Total Carbs</div>
              </div>
              <div className="stat-card">
                <div className="stat-icon">🥑</div>
                <div className="stat-value">{stats.totalFat}g</div>
                <div className="stat-label">Total Fat</div>
              </div>
            </div>

            {/* Macro Progress Bars */}
            <div style={{ marginTop: '30px', padding: '20px', background: 'white', borderRadius: '10px', boxShadow: '0 2px 8px rgba(0,0,0,0.1)' }}>
              <h3 style={{ marginBottom: '20px', fontSize: '18px', color: '#1f2937' }}>Macro Distribution</h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '15px' }}>
                {/* Protein Bar */}
                <div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '5px', fontSize: '14px' }}>
                    <span>💪 Protein</span>
                    <span style={{ fontWeight: 'bold' }}>{stats.totalProtein}g ({((parseFloat(stats.totalProtein) * 4 / parseFloat(stats.totalCalories)) * 100 || 0).toFixed(0)}%)</span>
                  </div>
                  <div style={{ width: '100%', height: '12px', background: '#e5e7eb', borderRadius: '6px', overflow: 'hidden' }}>
                    <div style={{ width: `${(parseFloat(stats.totalProtein) * 4 / parseFloat(stats.totalCalories)) * 100 || 0}%`, height: '100%', background: 'linear-gradient(90deg, #3b82f6, #2563eb)', transition: 'width 0.3s ease' }}></div>
                  </div>
                </div>
                {/* Carbs Bar */}
                <div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '5px', fontSize: '14px' }}>
                    <span>🍞 Carbs</span>
                    <span style={{ fontWeight: 'bold' }}>{stats.totalCarbs}g ({((parseFloat(stats.totalCarbs) * 4 / parseFloat(stats.totalCalories)) * 100 || 0).toFixed(0)}%)</span>
                  </div>
                  <div style={{ width: '100%', height: '12px', background: '#e5e7eb', borderRadius: '6px', overflow: 'hidden' }}>
                    <div style={{ width: `${(parseFloat(stats.totalCarbs) * 4 / parseFloat(stats.totalCalories)) * 100 || 0}%`, height: '100%', background: 'linear-gradient(90deg, #f59e0b, #d97706)', transition: 'width 0.3s ease' }}></div>
                  </div>
                </div>
                {/* Fat Bar */}
                <div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '5px', fontSize: '14px' }}>
                    <span>🥑 Fat</span>
                    <span style={{ fontWeight: 'bold' }}>{stats.totalFat}g ({((parseFloat(stats.totalFat) * 9 / parseFloat(stats.totalCalories)) * 100 || 0).toFixed(0)}%)</span>
                  </div>
                  <div style={{ width: '100%', height: '12px', background: '#e5e7eb', borderRadius: '6px', overflow: 'hidden' }}>
                    <div style={{ width: `${(parseFloat(stats.totalFat) * 9 / parseFloat(stats.totalCalories)) * 100 || 0}%`, height: '100%', background: 'linear-gradient(90deg, #10b981, #059669)', transition: 'width 0.3s ease' }}></div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Food Form */}
        <div className="food-form-section">
          <h2 className="section-title">Log Food</h2>
          <form onSubmit={handleSubmit} className="food-form">
            <div className="form-row">
              <div className="form-group">
                <label className="form-label">
                  <span className="label-icon">🍽️</span>
                  Food Name
                </label>
                <input
                  name="name"
                  type="text"
                  placeholder="e.g., Grilled Chicken Breast"
                  value={form.name}
                  onChange={handleChange}
                  className="form-input"
                  required
                />
              </div>
              <div className="form-group">
                <label className="form-label">
                  <span className="label-icon">🔥</span>
                  Calories
                </label>
                <input
                  name="calories"
                  type="number"
                  min="0"
                  placeholder="250"
                  value={form.calories}
                  onChange={handleChange}
                  className="form-input"
                  required
                />
              </div>
            </div>
            <div className="form-row">
              <div className="form-group">
                <label className="form-label">
                  <span className="label-icon">💪</span>
                  Protein (g)
                </label>
                <input
                  name="protein"
                  type="number"
                  step="0.1"
                  min="0"
                  placeholder="25"
                  value={form.protein}
                  onChange={handleChange}
                  className="form-input"
                  required
                />
              </div>
              <div className="form-group">
                <label className="form-label">
                  <span className="label-icon">🍞</span>
                  Carbs (g)
                </label>
                <input
                  name="carbs"
                  type="number"
                  step="0.1"
                  min="0"
                  placeholder="15"
                  value={form.carbs}
                  onChange={handleChange}
                  className="form-input"
                  required
                />
              </div>
            </div>
            <div className="form-row">
              <div className="form-group">
                <label className="form-label">
                  <span className="label-icon">🥑</span>
                  Fat (g)
                </label>
                <input
                  name="fat"
                  type="number"
                  step="0.1"
                  min="0"
                  placeholder="8"
                  value={form.fat}
                  onChange={handleChange}
                  className="form-input"
                  required
                />
              </div>
              <div className="form-group">
                <label className="form-label">
                  <span className="label-icon">🍯</span>
                  Sugar (g)
                </label>
                <input
                  name="sugar"
                  type="number"
                  step="0.1"
                  min="0"
                  placeholder="5"
                  value={form.sugar}
                  onChange={handleChange}
                  className="form-input"
                  required
                />
              </div>
            </div>
            <div className="form-row">
              <div className="form-group">
                <label className="form-label">
                  <span className="label-icon">⏰</span>
                  Meal Type
                </label>
                <select
                  name="mealType"
                  value={form.mealType}
                  onChange={handleChange}
                  className="form-select"
                  required
                >
                  <option value="Breakfast">Breakfast</option>
                  <option value="Lunch">Lunch</option>
                  <option value="Dinner">Dinner</option>
                  <option value="Snack">Snack</option>
                </select>
              </div>
            </div>
            <div className="form-actions">
              <button 
                type="submit" 
                className="submit-btn"
                disabled={saving}
              >
                {saving ? (
                  <>
                    <span className="spinner"></span>
                    Logging...
                  </>
                ) : (
                  'Log Food'
                )}
              </button>
            </div>
          </form>
        </div>

        {/* Food History */}
        <div className="food-history-section">
          <h2 className="section-title">Food History</h2>
          {loading ? (
            <div className="loading-state">
              <div className="spinner"></div>
              <p>Loading food data...</p>
            </div>
          ) : entries.length === 0 ? (
            <div className="empty-state">
              <div className="empty-icon">🍽️</div>
              <h3>No Food Data Yet</h3>
              <p>Start tracking your meals to monitor your nutrition and maintain a healthy diet.</p>
            </div>
          ) : (
            <div className="food-entries">
              {entries.map(entry => (
                <div key={entry.id} className="food-entry">
                  <div className="entry-header">
                    <div className="entry-name">{entry.name}</div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                      <div className="entry-meal-type" style={{ color: getMealTypeColor(entry.meal_type || entry.mealType) }}>
                        {getMealTypeIcon(entry.meal_type || entry.mealType)} {entry.meal_type || entry.mealType}
                      </div>
                      <button 
                        onClick={() => handleDelete(entry.id)}
                        className="delete-btn"
                        style={{
                          background: '#ef4444',
                          color: 'white',
                          border: 'none',
                          padding: '5px 12px',
                          borderRadius: '5px',
                          cursor: 'pointer',
                          fontSize: '12px'
                        }}
                      >
                        🗑️ Delete
                      </button>
                    </div>
                  </div>
                  <div className="entry-nutrition">
                    <div className="nutrition-main">
                      <span className="calories">{entry.calories} calories</span>
                    </div>
                    <div className="nutrition-details">
                      <span className="macro">P: {entry.protein}g</span>
                      <span className="macro">C: {entry.carbs || 0}g</span>
                      <span className="macro">F: {entry.fat || 0}g</span>
                      <span className="macro">S: {entry.sugar}g</span>
                    </div>
                  </div>
                  <div className="entry-date">{entry.entry_date}</div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
