import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import './Dashboard.css';
import './Workouts.css';

const BASE_URL = process.env.REACT_APP_API_URL;

export default function Workouts() {
  const navigate = useNavigate();
  const [workouts, setWorkouts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    type: 'strength',
    duration: '',
    difficulty: 'medium',
    description: '',
    exercises: []
  });

  const workoutTypes = [
    { value: 'strength', label: '💪 Strength Training', icon: '💪' },
    { value: 'cardio', label: '❤️ Cardio', icon: '❤️' },
    { value: 'flexibility', label: '🧘 Flexibility', icon: '🧘' },
    { value: 'hiit', label: '⚡ HIIT', icon: '⚡' },
    { value: 'yoga', label: '🧘‍♀️ Yoga', icon: '🧘‍♀️' },
    { value: 'sports', label: '⚽ Sports', icon: '⚽' }
  ];

  const difficultyLevels = [
    { value: 'beginner', label: 'Beginner', color: '#00b894' },
    { value: 'medium', label: 'Medium', color: '#fdcb6e' },
    { value: 'advanced', label: 'Advanced', color: '#e17055' }
  ];

  const sampleWorkouts = [
    {
      id: 1,
      name: 'Full Body Strength',
      type: 'strength',
      duration: 45,
      difficulty: 'medium',
      description: 'Complete full body workout targeting all major muscle groups',
      exercises: ['Squats', 'Push-ups', 'Rows', 'Lunges', 'Planks'],
      lastUsed: '2024-01-15'
    },
    {
      id: 2,
      name: 'HIIT Cardio Blast',
      type: 'hiit',
      duration: 30,
      difficulty: 'advanced',
      description: 'High-intensity interval training for maximum calorie burn',
      exercises: ['Burpees', 'Mountain Climbers', 'Jump Squats', 'High Knees'],
      lastUsed: '2024-01-14'
    },
    {
      id: 3,
      name: 'Morning Yoga Flow',
      type: 'yoga',
      duration: 20,
      difficulty: 'beginner',
      description: 'Gentle morning yoga sequence to start your day',
      exercises: ['Sun Salutation', 'Warrior Poses', 'Tree Pose', 'Child\'s Pose'],
      lastUsed: '2024-01-13'
    }
  ];

  useEffect(() => {
    // Simulate loading workouts
    setTimeout(() => {
      setWorkouts(sampleWorkouts);
      setLoading(false);
    }, 1000);
  }, []);

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const addExercise = () => {
    const exercise = prompt('Enter exercise name:');
    if (exercise && exercise.trim()) {
      setFormData(prev => ({
        ...prev,
        exercises: [...prev.exercises, exercise.trim()]
      }));
    }
  };

  const removeExercise = (index) => {
    setFormData(prev => ({
      ...prev,
      exercises: prev.exercises.filter((_, i) => i !== index)
    }));
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    
    if (!formData.name || !formData.duration) {
      alert('Please fill in all required fields');
      return;
    }

    const newWorkout = {
      id: Date.now(),
      ...formData,
      lastUsed: new Date().toISOString().split('T')[0]
    };

    setWorkouts(prev => [newWorkout, ...prev]);
    setFormData({
      name: '',
      type: 'strength',
      duration: '',
      difficulty: 'medium',
      description: '',
      exercises: []
    });
    setShowForm(false);
  };

  const startWorkout = (workout) => {
    // Here you would typically navigate to a workout session page
    alert(`Starting workout: ${workout.name}`);
  };

  const deleteWorkout = (id) => {
    if (window.confirm('Are you sure you want to delete this workout?')) {
      setWorkouts(prev => prev.filter(w => w.id !== id));
    }
  };

  const getWorkoutTypeIcon = (type) => {
    return workoutTypes.find(t => t.value === type)?.icon || '💪';
  };

  const getDifficultyColor = (difficulty) => {
    return difficultyLevels.find(d => d.value === difficulty)?.color || '#fdcb6e';
  };

  if (loading) {
    return (
      <div className="workouts-page">
        <div className="loading-container">
          <div className="spinner"></div>
          <p>Loading workouts...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="workouts-page">
      {/* Header */}
      <header className="workouts-header">
        <div className="header-left">
          <button className="action-btn back-btn" onClick={() => navigate('/dashboard')}>
            ← Back
          </button>
          <div className="header-content">
            <h1 className="workouts-title">💪 Workout Library</h1>
            <p className="workouts-subtitle">Plan, save, and track your workouts</p>
          </div>
        </div>
        
        <div className="header-right">
          <button 
            className="action-btn add-btn"
            onClick={() => setShowForm(true)}
          >
            + Add Workout
          </button>
        </div>
      </header>

      {/* Main Content */}
      <div className="workouts-content">
        {/* Quick Stats */}
        <section className="stats-section">
          <div className="stats-grid">
            <div className="stat-card">
              <div className="stat-icon">💪</div>
              <div className="stat-content">
                <h3 className="stat-label">Total Workouts</h3>
                <div className="stat-value">{workouts.length}</div>
              </div>
            </div>
            
            <div className="stat-card">
              <div className="stat-icon">⏱️</div>
              <div className="stat-content">
                <h3 className="stat-label">Avg Duration</h3>
                <div className="stat-value">
                  {workouts.length > 0 
                    ? Math.round(workouts.reduce((sum, w) => sum + w.duration, 0) / workouts.length)
                    : 0
                  } min
                </div>
              </div>
            </div>
            
            <div className="stat-card">
              <div className="stat-icon">🎯</div>
              <div className="stat-content">
                <h3 className="stat-label">Most Used Type</h3>
                <div className="stat-value">
                  {workouts.length > 0 
                    ? workoutTypes.find(t => t.value === workouts[0].type)?.label.split(' ')[1] || 'Strength'
                    : 'None'
                  }
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* Workout Form Modal */}
        {showForm && (
          <div className="modal-overlay" onClick={() => setShowForm(false)}>
            <div className="modal-content" onClick={e => e.stopPropagation()}>
              <div className="modal-header">
                <h2 className="modal-title">Create New Workout</h2>
                <button 
                  className="modal-close"
                  onClick={() => setShowForm(false)}
                >
                  ×
                </button>
              </div>
              
              <form onSubmit={handleSubmit} className="workout-form">
                <div className="form-row">
                  <div className="form-group">
                    <label className="form-label">Workout Name *</label>
                    <input
                      type="text"
                      name="name"
                      value={formData.name}
                      onChange={handleInputChange}
                      placeholder="e.g., Full Body Strength"
                      className="form-input"
                      required
                    />
                  </div>
                  
                  <div className="form-group">
                    <label className="form-label">Type</label>
                    <select
                      name="type"
                      value={formData.type}
                      onChange={handleInputChange}
                      className="form-select"
                    >
                      {workoutTypes.map(type => (
                        <option key={type.value} value={type.value}>
                          {type.label}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>
                
                <div className="form-row">
                  <div className="form-group">
                    <label className="form-label">Duration (minutes) *</label>
                    <input
                      type="number"
                      name="duration"
                      value={formData.duration}
                      onChange={handleInputChange}
                      placeholder="45"
                      className="form-input"
                      min="5"
                      max="180"
                      required
                    />
                  </div>
                  
                  <div className="form-group">
                    <label className="form-label">Difficulty</label>
                    <select
                      name="difficulty"
                      value={formData.difficulty}
                      onChange={handleInputChange}
                      className="form-select"
                    >
                      {difficultyLevels.map(level => (
                        <option key={level.value} value={level.value}>
                          {level.label}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>
                
                <div className="form-group">
                  <label className="form-label">Description</label>
                  <textarea
                    name="description"
                    value={formData.description}
                    onChange={handleInputChange}
                    placeholder="Describe your workout..."
                    className="form-textarea"
                    rows="3"
                  />
                </div>
                
                <div className="form-group">
                  <label className="form-label">Exercises</label>
                  <div className="exercises-container">
                    {formData.exercises.map((exercise, index) => (
                      <div key={index} className="exercise-tag">
                        <span>{exercise}</span>
                        <button
                          type="button"
                          className="remove-exercise"
                          onClick={() => removeExercise(index)}
                        >
                          ×
                        </button>
                      </div>
                    ))}
                    <button
                      type="button"
                      className="add-exercise-btn"
                      onClick={addExercise}
                    >
                      + Add Exercise
                    </button>
                  </div>
                </div>
                
                <div className="form-actions">
                  <button
                    type="button"
                    className="action-btn cancel-btn"
                    onClick={() => setShowForm(false)}
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="action-btn submit-btn"
                  >
                    Create Workout
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Workouts List */}
        <section className="workouts-list">
          <h2 className="section-title">Your Workouts</h2>
          
          {workouts.length === 0 ? (
            <div className="empty-workouts">
              <div className="empty-icon">💪</div>
              <h3 className="empty-title">No workouts yet</h3>
              <p className="empty-description">
                Create your first workout to start building your fitness routine
              </p>
              <button 
                className="empty-btn"
                onClick={() => setShowForm(true)}
              >
                Create Workout
              </button>
            </div>
          ) : (
            <div className="workouts-grid">
              {workouts.map(workout => (
                <div key={workout.id} className="workout-card">
                  <div className="workout-header">
                    <div className="workout-type-icon">
                      {getWorkoutTypeIcon(workout.type)}
                    </div>
                    <div className="workout-meta">
                      <div className="workout-difficulty" style={{ backgroundColor: getDifficultyColor(workout.difficulty) }}>
                        {workout.difficulty}
                      </div>
                      <div className="workout-duration">
                        {workout.duration} min
                      </div>
                    </div>
                  </div>
                  
                  <div className="workout-content">
                    <h3 className="workout-name">{workout.name}</h3>
                    {workout.description && (
                      <p className="workout-description">{workout.description}</p>
                    )}
                    
                    {workout.exercises.length > 0 && (
                      <div className="exercises-preview">
                        <h4 className="exercises-title">Exercises:</h4>
                        <div className="exercises-list">
                          {workout.exercises.slice(0, 3).map((exercise, index) => (
                            <span key={index} className="exercise-item">
                              {exercise}
                            </span>
                          ))}
                          {workout.exercises.length > 3 && (
                            <span className="exercise-more">
                              +{workout.exercises.length - 3} more
                            </span>
                          )}
                        </div>
                      </div>
                    )}
                  </div>
                  
                  <div className="workout-footer">
                    <div className="workout-last-used">
                      Last used: {workout.lastUsed}
                    </div>
                    <div className="workout-actions">
                      <button
                        className="action-btn start-btn"
                        onClick={() => startWorkout(workout)}
                      >
                        Start
                      </button>
                      <button
                        className="action-btn delete-btn"
                        onClick={() => deleteWorkout(workout.id)}
                      >
                        Delete
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>
      </div>
    </div>
  );
}
