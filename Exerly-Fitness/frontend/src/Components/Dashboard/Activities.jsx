// frontend/src/Components/Dashboard/Activities.jsx
import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import './Activities.css';
import API_CONFIG from '../../config';

const BASE_URL = API_CONFIG.BASE_URL;

export default function Activities() {
  const [entries, setEntries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({
    activity: '',
    duration_min: '',
    calories: '',
    intensity: 'Moderate',
    type: 'Cardio'
  });
  const navigate = useNavigate();

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) return navigate('/');
    
    fetchActivitiesData();
  }, [navigate]);

  const fetchActivitiesData = async () => {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${BASE_URL}/api/activities`, {
        headers: { Authorization: 'Bearer ' + token }
      });
      
      if (res.status === 401) {
        navigate('/');
        return;
      }
      
      if (!res.ok) throw new Error(`Fetch failed: ${res.status}`);
      
      const data = await res.json();
      setEntries(Array.isArray(data) ? data : []);
    } catch (error) {
      console.error('Error fetching activities data:', error);
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

      const res = await fetch(`${BASE_URL}/api/activities`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer ' + token
        },
        body: JSON.stringify({
          activity: form.activity,
          duration_min: form.duration_min,
          calories: form.calories,
          intensity: form.intensity,
          type: form.type
        })
      });

      if (res.ok) {
        const entry = await res.json();
        setEntries([entry, ...entries]);
        setForm({ 
          activity: '', 
          duration_min: '', 
          calories: '', 
          intensity: 'Moderate', 
          type: 'Cardio' 
        });
        alert('✅ Activity logged successfully!');
      } else if (res.status === 401) {
        navigate('/');
      } else {
        const errorText = await res.text();
        console.error('Save failed:', errorText);
        alert('Error: ' + errorText);
      }
    } catch (error) {
      console.error('Error saving activity data:', error);
      alert('Error saving activity data');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure you want to delete this activity?')) return;
    
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${BASE_URL}/api/activities/${id}`, {
        method: 'DELETE',
        headers: { Authorization: 'Bearer ' + token }
      });

      if (res.ok) {
        setEntries(entries.filter(entry => entry.id !== id));
        alert('✅ Activity deleted successfully!');
      } else {
        alert('Error deleting activity');
      }
    } catch (error) {
      console.error('Error deleting activity:', error);
      alert('Error deleting activity');
    }
  };

  const calculateActivityStats = () => {
    if (entries.length === 0) return null;
    
    const totalCalories = entries.reduce((sum, entry) => sum + parseFloat(entry.calories || 0), 0);
    const totalDuration = entries.reduce((sum, entry) => sum + parseFloat(entry.duration_min || 0), 0);
    const avgCalories = totalCalories / entries.length;
    const avgDuration = totalDuration / entries.length;
    
    return {
      totalCalories: totalCalories.toFixed(0),
      totalDuration: totalDuration.toFixed(0),
      avgCalories: avgCalories.toFixed(0),
      avgDuration: avgDuration.toFixed(0),
      totalEntries: entries.length
    };
  };

  const stats = calculateActivityStats();

  const getActivityIcon = (activity) => {
    const activityLower = activity?.toLowerCase();
    if (activityLower.includes('run')) return '🏃‍♂️';
    if (activityLower.includes('walk')) return '🚶‍♂️';
    if (activityLower.includes('bike') || activityLower.includes('cycle')) return '🚴‍♂️';
    if (activityLower.includes('swim')) return '🏊‍♂️';
    if (activityLower.includes('gym') || activityLower.includes('weight')) return '🏋️‍♂️';
    if (activityLower.includes('yoga')) return '🧘‍♀️';
    if (activityLower.includes('dance')) return '💃';
    if (activityLower.includes('hike')) return '🥾';
    return '🏃‍♂️';
  };

  const getIntensityColor = (intensity) => {
    switch (intensity?.toLowerCase()) {
      case 'low': return '#10b981';
      case 'moderate': return '#f59e0b';
      case 'high': return '#ef4444';
      default: return '#6b7280';
    }
  };

  const formatDuration = (minutes) => {
    if (minutes < 60) return `${minutes} min`;
    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;
    return mins > 0 ? `${hours}h ${mins}m` : `${hours}h`;
  };

  return (
    <div className="activities-page">
      {/* Header */}
      <div className="activities-header">
        <button className="back-btn" onClick={() => navigate('/dashboard')}>
          Back to Dashboard
        </button>
        <div className="header-content">
          <h1 className="activities-title">Activity Tracker</h1>
          <p className="activities-subtitle">Track your workouts and stay active</p>
        </div>
      </div>

      {/* Main Content */}
      <div className="activities-content">
        {/* Quick Stats */}
        {stats && (
          <div className="stats-section">
            <h2 className="section-title">Today's Activity</h2>
            <div className="stats-grid">
              <div className="stat-card">
                <div className="stat-icon">🔥</div>
                <div className="stat-value">{stats.totalCalories}</div>
                <div className="stat-label">Total Calories Burned</div>
              </div>
              <div className="stat-card">
                <div className="stat-icon">⏰</div>
                <div className="stat-value">{formatDuration(stats.totalDuration)}</div>
                <div className="stat-label">Total Duration</div>
              </div>
              <div className="stat-card">
                <div className="stat-icon">📊</div>
                <div className="stat-value">{stats.avgCalories}</div>
                <div className="stat-label">Avg Calories per Activity</div>
              </div>
              <div className="stat-card">
                <div className="stat-icon">🎯</div>
                <div className="stat-value">{stats.totalEntries}</div>
                <div className="stat-label">Total Activities</div>
              </div>
            </div>
          </div>
        )}

        {/* Activity Form */}
        <div className="activity-form-section">
          <h2 className="section-title">Log Activity</h2>
          <form onSubmit={handleSubmit} className="activity-form">
            <div className="form-row">
              <div className="form-group">
                <label className="form-label">
                  <span className="label-icon">🏃‍♂️</span>
                  Activity Name
                </label>
                <input
                  name="activity"
                  type="text"
                  placeholder="e.g., Running, Weight Training"
                  value={form.activity}
                  onChange={handleChange}
                  className="form-input"
                  required
                />
              </div>
              <div className="form-group">
                <label className="form-label">
                  <span className="label-icon">⏰</span>
                  Duration (minutes)
                </label>
                <input
                  name="duration_min"
                  type="number"
                  min="1"
                  placeholder="30"
                  value={form.duration_min}
                  onChange={handleChange}
                  className="form-input"
                  required
                />
              </div>
            </div>
            <div className="form-row">
              <div className="form-group">
                <label className="form-label">
                  <span className="label-icon">🔥</span>
                  Calories Burned
                </label>
                <input
                  name="calories"
                  type="number"
                  min="0"
                  placeholder="300"
                  value={form.calories}
                  onChange={handleChange}
                  className="form-input"
                  required
                />
              </div>
              <div className="form-group">
                <label className="form-label">
                  <span className="label-icon">⚡</span>
                  Intensity Level
                </label>
                <select
                  name="intensity"
                  value={form.intensity}
                  onChange={handleChange}
                  className="form-select"
                  required
                >
                  <option value="Low">Low</option>
                  <option value="Moderate">Moderate</option>
                  <option value="High">High</option>
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
                  'Log Activity'
                )}
              </button>
            </div>
          </form>
        </div>

        {/* Activity History */}
        <div className="activity-history-section">
          <h2 className="section-title">Activity History</h2>
          {loading ? (
            <div className="loading-state">
              <div className="spinner"></div>
              <p>Loading activity data...</p>
            </div>
          ) : entries.length === 0 ? (
            <div className="empty-state">
              <div className="empty-icon">🏃‍♂️</div>
              <h3>No Activities Yet</h3>
              <p>Start tracking your workouts to see your progress and stay motivated.</p>
            </div>
          ) : (
            <div className="activity-entries">
              {entries.map(entry => (
                <div key={entry.id} className="activity-entry">
                  <div className="entry-header">
                    <div className="entry-activity">
                      <span className="activity-icon">{getActivityIcon(entry.activity)}</span>
                      {entry.activity}
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                      {entry.intensity && (
                        <div className="entry-intensity" style={{ color: getIntensityColor(entry.intensity) }}>
                          ⚡ {entry.intensity}
                        </div>
                      )}
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
                  <div className="entry-details">
                    <div className="detail-main">
                      <span className="calories-burned">{entry.calories} calories burned</span>
                    </div>
                    <div className="detail-secondary">
                      <span className="duration">{formatDuration(entry.duration_min)}</span>
                      <span className="date">{entry.entry_date}</span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
