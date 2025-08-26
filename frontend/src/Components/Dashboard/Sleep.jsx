import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import './Sleep.css';

const BASE_URL = process.env.REACT_APP_API_URL;

export default function Sleep() {
  const [entries, setEntries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({
    hours: '',
    quality: 'Good',
    bedtime: '',
    wakeTime: ''
  });
  const navigate = useNavigate();

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) return navigate('/');
    
    fetchSleepData();
  }, [navigate]);

  const fetchSleepData = async () => {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${BASE_URL}/api/sleep`, {
        headers: { Authorization: 'Bearer ' + token }
      });
      
      if (res.status === 401) {
        navigate('/');
        return;
      }
      
      const data = await res.json();
      setEntries(Array.isArray(data) ? data : []);
    } catch (error) {
      console.error('Error fetching sleep data:', error);
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
        setForm({ hours: '', quality: 'Good', bedtime: '', wakeTime: '' });
        // Show success message or toast
      } else if (res.status === 401) {
        navigate('/');
      } else {
        const errorText = await res.text();
        console.error('Save failed:', errorText);
        alert('Error: ' + errorText);
      }
    } catch (error) {
      console.error('Error saving sleep data:', error);
      alert('Error saving sleep data');
    } finally {
      setSaving(false);
    }
  };

  const getSleepQualityColor = (quality) => {
    switch (quality?.toLowerCase()) {
      case 'excellent': return '#10b981';
      case 'good': return '#3b82f6';
      case 'fair': return '#f59e0b';
      case 'poor': return '#ef4444';
      default: return '#6b7280';
    }
  };

  const getSleepQualityIcon = (quality) => {
    switch (quality?.toLowerCase()) {
      case 'excellent': return '😴';
      case 'good': return '😊';
      case 'fair': return '😐';
      case 'poor': return '😫';
      default: return '😴';
    }
  };

  const calculateSleepStats = () => {
    if (entries.length === 0) return null;
    
    const totalHours = entries.reduce((sum, entry) => sum + parseFloat(entry.hours || 0), 0);
    const avgHours = totalHours / entries.length;
    const qualityCounts = entries.reduce((acc, entry) => {
      const quality = entry.quality?.toLowerCase() || 'unknown';
      acc[quality] = (acc[quality] || 0) + 1;
      return acc;
    }, {});
    
    const mostCommonQuality = Object.entries(qualityCounts)
      .sort(([,a], [,b]) => b - a)[0]?.[0] || 'N/A';
    
    return { avgHours: avgHours.toFixed(1), mostCommonQuality, totalEntries: entries.length };
  };

  const stats = calculateSleepStats();

  return (
    <div className="sleep-page">
      {/* Header */}
      <div className="sleep-header">
        <button className="back-btn" onClick={() => navigate('/dashboard')}>
          Back to Dashboard
        </button>
        <div className="header-content">
          <h1 className="sleep-title">Sleep Tracker</h1>
          <p className="sleep-subtitle">Track your sleep patterns and improve your rest</p>
        </div>
      </div>

      {/* Main Content */}
      <div className="sleep-content">
        {/* Quick Stats */}
        {stats && (
          <div className="stats-section">
            <h2 className="section-title">Sleep Overview</h2>
            <div className="stats-grid">
              <div className="stat-card">
                <div className="stat-icon">😴</div>
                <div className="stat-value">{stats.avgHours}</div>
                <div className="stat-label">Avg Hours</div>
              </div>
              <div className="stat-card">
                <div className="stat-icon">📊</div>
                <div className="stat-value">{stats.mostCommonQuality}</div>
                <div className="stat-label">Most Common Quality</div>
              </div>
              <div className="stat-card">
                <div className="stat-icon">📝</div>
                <div className="stat-value">{stats.totalEntries}</div>
                <div className="stat-label">Total Entries</div>
              </div>
            </div>
          </div>
        )}

        {/* Sleep Form */}
        <div className="sleep-form-section">
          <h2 className="section-title">Log Sleep</h2>
          <form onSubmit={handleSubmit} className="sleep-form">
            <div className="form-row">
              <div className="form-group">
                <label className="form-label">
                  <span className="label-icon">⏰</span>
                  Hours Slept
                </label>
                <input
                  name="hours"
                  type="number"
                  step="0.1"
                  min="0"
                  max="24"
                  placeholder="7.5"
                  value={form.hours}
                  onChange={handleChange}
                  className="form-input"
                  required
                />
              </div>
              <div className="form-group">
                <label className="form-label">
                  <span className="label-icon">⭐</span>
                  Sleep Quality
                </label>
                <select
                  name="quality"
                  value={form.quality}
                  onChange={handleChange}
                  className="form-select"
                  required
                >
                  <option value="Excellent">Excellent</option>
                  <option value="Good">Good</option>
                  <option value="Fair">Fair</option>
                  <option value="Poor">Poor</option>
                </select>
              </div>
            </div>
            <div className="form-row">
              <div className="form-group">
                <label className="form-label">
                  <span className="label-icon">🌙</span>
                  Bedtime (Optional)
                </label>
                <input
                  name="bedtime"
                  type="time"
                  value={form.bedtime}
                  onChange={handleChange}
                  className="form-input"
                />
              </div>
              <div className="form-group">
                <label className="form-label">
                  <span className="label-icon">☀️</span>
                  Wake Time (Optional)
                </label>
                <input
                  name="wakeTime"
                  type="time"
                  value={form.wakeTime}
                  onChange={handleChange}
                  className="form-input"
                />
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
                  'Log Sleep'
                )}
              </button>
            </div>
          </form>
        </div>

        {/* Sleep History */}
        <div className="sleep-history-section">
          <h2 className="section-title">Sleep History</h2>
          {loading ? (
            <div className="loading-state">
              <div className="spinner"></div>
              <p>Loading sleep data...</p>
            </div>
          ) : entries.length === 0 ? (
            <div className="empty-state">
              <div className="empty-icon">😴</div>
              <h3>No Sleep Data Yet</h3>
              <p>Start tracking your sleep to see your patterns and improve your rest quality.</p>
            </div>
          ) : (
            <div className="sleep-entries">
              {entries.map(entry => (
                <div key={entry.id} className="sleep-entry">
                  <div className="entry-header">
                    <div className="entry-quality" style={{ color: getSleepQualityColor(entry.quality) }}>
                      {getSleepQualityIcon(entry.quality)} {entry.quality}
                    </div>
                    <div className="entry-date">{entry.entry_date}</div>
                  </div>
                  <div className="entry-hours">
                    <span className="hours-value">{entry.hours}</span>
                    <span className="hours-unit">hours</span>
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
