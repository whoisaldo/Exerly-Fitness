import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import './Dashboard.css';
import './Goals.css';
import API_CONFIG from '../../config';

const BASE_URL = API_CONFIG.BASE_URL;

export default function Goals() {
  const navigate = useNavigate();
  const [goals, setGoals] = useState({
    dailyCalories: '',
    weeklyWorkouts: '',
    dailySteps: '',
    weeklyWeight: '',
    sleepHours: '',
    waterIntake: ''
  });
  const [loading, setLoading] = useState(false);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    const fetchGoals = async () => {
      try {
        const token = localStorage.getItem('token');
        if (!token) return navigate('/');

        const res = await fetch(`${BASE_URL}/api/goals`, {
          headers: { Authorization: 'Bearer ' + token }
        });

        if (res.ok) {
          const data = await res.json();
          if (data && Object.keys(data).length > 0) {
            setGoals({
              dailyCalories: data.daily_calories || '',
              weeklyWorkouts: data.weekly_workouts || '',
              dailySteps: data.daily_steps || '',
              weeklyWeight: data.weekly_weight || '',
              sleepHours: data.sleep_hours || '',
              waterIntake: data.water_intake || ''
            });
          }
        }
      } catch (err) {
        console.error('Error fetching goals:', err);
      }
    };

    fetchGoals();
  }, [navigate]);

  const handleChange = (e) => {
    const { name, value } = e.target;
    setGoals(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    
    try {
      const token = localStorage.getItem('token');
      if (!token) return navigate('/');

      const res = await fetch(`${BASE_URL}/api/goals`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer ' + token
        },
        body: JSON.stringify(goals)
      });

      if (res.ok) {
        setSaved(true);
        setTimeout(() => setSaved(false), 3000);
      } else if (res.status === 401) {
        navigate('/');
      } else {
        alert('Error saving goals');
      }
    } catch (err) {
      console.error('Failed to save goals:', err);
      alert('Error saving goals');
    } finally {
      setLoading(false);
    }
  };

  const resetGoals = () => {
    setGoals({
      dailyCalories: '',
      weeklyWorkouts: '',
      dailySteps: '',
      weeklyWeight: '',
      sleepHours: '',
      waterIntake: ''
    });
  };

  return (
    <div className="goals-page">
      {/* Header */}
      <header className="goals-header">
        <div className="header-left">
          <button className="action-btn back-btn" onClick={() => navigate('/dashboard')}>
            ← Back
          </button>
          <div className="header-content">
            <h1 className="goals-title">🎯 Fitness Goals</h1>
            <p className="goals-subtitle">Set and track your fitness objectives</p>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <div className="goals-content">
        {/* Goals Form */}
        <section className="goals-form-section">
          <div className="form-header">
            <h2 className="section-title">Set Your Goals</h2>
            <p className="section-description">
              Define your targets to stay motivated and track your progress
            </p>
          </div>

          <form onSubmit={handleSubmit} className="goals-form">
            <div className="form-grid">
              {/* Daily Calories */}
              <div className="form-group">
                <label className="form-label">
                  <span className="label-icon">🔥</span>
                  Daily Calories
                </label>
                <input
                  type="number"
                  name="dailyCalories"
                  value={goals.dailyCalories}
                  onChange={handleChange}
                  placeholder="e.g., 2000"
                  className="form-input"
                  min="0"
                />
                <span className="input-unit">kcal</span>
              </div>

              {/* Weekly Workouts */}
              <div className="form-group">
                <label className="form-label">
                  <span className="label-icon">💪</span>
                  Weekly Workouts
                </label>
                <input
                  type="number"
                  name="weeklyWorkouts"
                  value={goals.weeklyWorkouts}
                  onChange={handleChange}
                  placeholder="e.g., 4"
                  className="form-input"
                  min="0"
                  max="7"
                />
                <span className="input-unit">times</span>
              </div>

              {/* Daily Steps */}
              <div className="form-group">
                <label className="form-label">
                  <span className="label-icon">👟</span>
                  Daily Steps
                </label>
                <input
                  type="number"
                  name="dailySteps"
                  value={goals.dailySteps}
                  onChange={handleChange}
                  placeholder="e.g., 10000"
                  className="form-input"
                  min="0"
                />
                <span className="input-unit">steps</span>
              </div>

              {/* Weekly Weight */}
              <div className="form-group">
                <label className="form-label">
                  <span className="label-icon">⚖️</span>
                  Weekly Weight Goal
                </label>
                <input
                  type="number"
                  name="weeklyWeight"
                  value={goals.weeklyWeight}
                  onChange={handleChange}
                  placeholder="e.g., -0.5"
                  className="form-input"
                  step="0.1"
                />
                <span className="input-unit">kg</span>
              </div>

              {/* Sleep Hours */}
              <div className="form-group">
                <label className="form-label">
                  <span className="label-icon">😴</span>
                  Daily Sleep
                </label>
                <input
                  type="number"
                  name="sleepHours"
                  value={goals.sleepHours}
                  onChange={handleChange}
                  placeholder="e.g., 8"
                  className="form-input"
                  min="0"
                  max="24"
                  step="0.5"
                />
                <span className="input-unit">hours</span>
              </div>

              {/* Water Intake */}
              <div className="form-group">
                <label className="form-label">
                  <span className="label-icon">💧</span>
                  Daily Water
                </label>
                <input
                  type="number"
                  name="waterIntake"
                  value={goals.waterIntake}
                  onChange={handleChange}
                  placeholder="e.g., 2.5"
                  className="form-input"
                  min="0"
                  step="0.1"
                />
                <span className="input-unit">liters</span>
              </div>
            </div>

            {/* Form Actions */}
            <div className="form-actions">
              <button
                type="button"
                className="action-btn reset-btn"
                onClick={resetGoals}
                disabled={loading}
              >
                Reset
              </button>
              <button
                type="submit"
                className="action-btn submit-btn"
                disabled={loading}
              >
                {loading ? (
                  <>
                    <div className="spinner"></div>
                    Saving...
                  </>
                ) : (
                  'Save Goals'
                )}
              </button>
            </div>
          </form>

          {/* Success Message */}
          {saved && (
            <div className="success-message">
              <span className="success-icon">✅</span>
              Goals saved successfully!
            </div>
          )}
        </section>

        {/* Goals Overview */}
        <section className="goals-overview">
          <h2 className="section-title">Your Current Goals</h2>
          
          <div className="goals-grid">
            {Object.entries(goals).map(([key, value]) => {
              if (!value) return null;
              
              const goalConfig = {
                dailyCalories: { icon: '🔥', label: 'Daily Calories', unit: 'kcal', color: 'calories' },
                weeklyWorkouts: { icon: '💪', label: 'Weekly Workouts', unit: 'times', color: 'workouts' },
                dailySteps: { icon: '👟', label: 'Daily Steps', unit: 'steps', color: 'steps' },
                weeklyWeight: { icon: '⚖️', label: 'Weekly Weight', unit: 'kg', color: 'weight' },
                sleepHours: { icon: '😴', label: 'Daily Sleep', unit: 'hours', color: 'sleep' },
                waterIntake: { icon: '💧', label: 'Daily Water', unit: 'L', color: 'water' }
              };

              const config = goalConfig[key];
              if (!config) return null;

              return (
                <div key={key} className={`goal-card ${config.color}`}>
                  <div className="goal-icon">{config.icon}</div>
                  <div className="goal-content">
                    <h3 className="goal-label">{config.label}</h3>
                    <div className="goal-value">
                      {value} {config.unit}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          {Object.values(goals).every(goal => !goal) && (
            <div className="empty-goals">
              <div className="empty-icon">🎯</div>
              <h3 className="empty-title">No goals set yet</h3>
              <p className="empty-description">
                Set your first fitness goal above to start tracking your progress
              </p>
            </div>
          )}
        </section>

        {/* Tips Section */}
        <section className="tips-section">
          <h2 className="section-title">💡 Goal Setting Tips</h2>
          
          <div className="tips-grid">
            <div className="tip-card">
              <div className="tip-icon">🎯</div>
              <h3 className="tip-title">Be Specific</h3>
              <p className="tip-description">
                Set clear, measurable goals instead of vague ones like "get fit"
              </p>
            </div>
            
            <div className="tip-card">
              <div className="tip-icon">📈</div>
              <h3 className="tip-title">Start Small</h3>
              <p className="tip-description">
                Begin with achievable goals and gradually increase difficulty
              </p>
            </div>
            
            <div className="tip-card">
              <div className="tip-icon">⏰</div>
              <h3 className="tip-title">Set Deadlines</h3>
              <p className="tip-description">
                Give yourself realistic timeframes to stay motivated
              </p>
            </div>
            
            <div className="tip-card">
              <div className="tip-icon">📝</div>
              <h3 className="tip-title">Track Progress</h3>
              <p className="tip-description">
                Monitor your achievements to see how far you've come
              </p>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
}
