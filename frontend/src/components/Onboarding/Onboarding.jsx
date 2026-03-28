import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import API_CONFIG from '../../config';
import './Onboarding.css';

const { BASE_URL } = API_CONFIG;

const Onboarding = () => {
  const [currentStep, setCurrentStep] = useState(1);
  const [formData, setFormData] = useState({
    age: '',
    gender: '',
    height: '',
    weight: '',
    goal: '',
    experienceLevel: '',
    workoutDaysPerWeek: 3,
    equipmentAccess: 'full_gym'
  });
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errors, setErrors] = useState({});
  const navigate = useNavigate();

  const totalSteps = 5;

  const handleInputChange = (field, value) => {
    setFormData(prev => ({
      ...prev,
      [field]: value
    }));
    
    // Clear error when user starts typing
    if (errors[field]) {
      setErrors(prev => ({
        ...prev,
        [field]: ''
      }));
    }
  };

  const validateStep = (step) => {
    const newErrors = {};
    
    switch (step) {
      case 2:
        if (!formData.age || formData.age < 13 || formData.age > 100) {
          newErrors.age = 'Please enter a valid age (13-100)';
        }
        if (!formData.gender) {
          newErrors.gender = 'Please select your gender';
        }
        if (!formData.height || formData.height < 100 || formData.height > 250) {
          newErrors.height = 'Please enter a valid height (100-250 cm)';
        }
        if (!formData.weight || formData.weight < 30 || formData.weight > 300) {
          newErrors.weight = 'Please enter a valid weight (30-300 kg)';
        }
        break;
      case 3:
        if (!formData.goal) {
          newErrors.goal = 'Please select your fitness goal';
        }
        break;
      case 4:
        if (!formData.experienceLevel) {
          newErrors.experienceLevel = 'Please select your experience level';
        }
        break;
      case 5:
        if (!formData.workoutDaysPerWeek || formData.workoutDaysPerWeek < 1 || formData.workoutDaysPerWeek > 7) {
          newErrors.workoutDaysPerWeek = 'Please select 1-7 days per week';
        }
        if (!formData.equipmentAccess) {
          newErrors.equipmentAccess = 'Please select your equipment access';
        }
        break;
    }
    
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const nextStep = () => {
    if (validateStep(currentStep)) {
      setCurrentStep(prev => Math.min(prev + 1, totalSteps));
    }
  };

  const prevStep = () => {
    setCurrentStep(prev => Math.max(prev - 1, 1));
  };

  const handleSubmit = async () => {
    if (!validateStep(currentStep)) return;
    
    setIsSubmitting(true);
    
    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`${BASE_URL}/api/user/onboarding`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(formData)
      });

      if (!response.ok) {
        throw new Error('Failed to complete onboarding');
      }

      // Show success animation
      setTimeout(() => {
        navigate('/dashboard');
      }, 2000);
      
    } catch (error) {
      console.error('Onboarding error:', error);
      setErrors({ submit: 'Failed to complete onboarding. Please try again.' });
    } finally {
      setIsSubmitting(false);
    }
  };

  const renderStep = () => {
    switch (currentStep) {
      case 1:
        return (
          <div className="onboarding-step">
            <div className="step-icon">💪</div>
            <h1>Welcome to Exerly Fitness!</h1>
            <p>Let's personalize your experience in 2 minutes</p>
            <div className="welcome-features">
              <div className="feature">
                <span className="feature-icon">🎯</span>
                <span>Personalized workout plans</span>
              </div>
              <div className="feature">
                <span className="feature-icon">📊</span>
                <span>Track your progress</span>
              </div>
              <div className="feature">
                <span className="feature-icon">🤖</span>
                <span>AI-powered coaching</span>
              </div>
            </div>
          </div>
        );

      case 2:
        return (
          <div className="onboarding-step">
            <h2>Basic Information</h2>
            <p>Help us understand your starting point</p>
            
            <div className="form-group">
              <label>Age</label>
              <input
                type="number"
                value={formData.age}
                onChange={(e) => handleInputChange('age', parseInt(e.target.value))}
                placeholder="25"
                min="13"
                max="100"
                className={errors.age ? 'error' : ''}
              />
              {errors.age && <span className="error-text">{errors.age}</span>}
            </div>

            <div className="form-group">
              <label>Gender</label>
              <div className="radio-group">
                {['Male', 'Female', 'Other', 'Prefer not to say'].map(option => (
                  <label key={option} className="radio-option">
                    <input
                      type="radio"
                      name="gender"
                      value={option.toLowerCase()}
                      checked={formData.gender === option.toLowerCase()}
                      onChange={(e) => handleInputChange('gender', e.target.value)}
                    />
                    <span>{option}</span>
                  </label>
                ))}
              </div>
              {errors.gender && <span className="error-text">{errors.gender}</span>}
            </div>

            <div className="form-row">
              <div className="form-group">
                <label>Height (cm)</label>
                <input
                  type="number"
                  value={formData.height}
                  onChange={(e) => handleInputChange('height', parseInt(e.target.value))}
                  placeholder="175"
                  min="100"
                  max="250"
                  className={errors.height ? 'error' : ''}
                />
                {errors.height && <span className="error-text">{errors.height}</span>}
              </div>

              <div className="form-group">
                <label>Weight (kg)</label>
                <input
                  type="number"
                  value={formData.weight}
                  onChange={(e) => handleInputChange('weight', parseInt(e.target.value))}
                  placeholder="70"
                  min="30"
                  max="300"
                  className={errors.weight ? 'error' : ''}
                />
                {errors.weight && <span className="error-text">{errors.weight}</span>}
              </div>
            </div>
          </div>
        );

      case 3:
        return (
          <div className="onboarding-step">
            <h2>What's your main fitness goal?</h2>
            <p>Choose the goal that motivates you most</p>
            
            <div className="goal-cards">
              {[
                { id: 'lose_weight', icon: '🔥', title: 'Lose Weight', desc: 'Burn fat and get lean' },
                { id: 'build_muscle', icon: '💪', title: 'Build Muscle', desc: 'Gain strength and size' },
                { id: 'improve_endurance', icon: '🏃', title: 'Improve Endurance', desc: 'Build cardiovascular fitness' },
                { id: 'stay_healthy', icon: '⚖️', title: 'Stay Healthy', desc: 'Maintain current fitness' }
              ].map(goal => (
                <div
                  key={goal.id}
                  className={`goal-card ${formData.goal === goal.id ? 'selected' : ''}`}
                  onClick={() => handleInputChange('goal', goal.id)}
                >
                  <div className="goal-icon">{goal.icon}</div>
                  <h3>{goal.title}</h3>
                  <p>{goal.desc}</p>
                </div>
              ))}
            </div>
            {errors.goal && <span className="error-text">{errors.goal}</span>}
          </div>
        );

      case 4:
        return (
          <div className="onboarding-step">
            <h2>What's your fitness experience?</h2>
            <p>This helps us create the right plan for you</p>
            
            <div className="experience-cards">
              {[
                { id: 'beginner', icon: '🌱', title: 'Beginner', desc: '0-6 months experience', subtext: 'New to working out' },
                { id: 'intermediate', icon: '🚀', title: 'Intermediate', desc: '6 months - 2 years', subtext: 'Some experience' },
                { id: 'advanced', icon: '💎', title: 'Advanced', desc: '2+ years experience', subtext: 'Very experienced' }
              ].map(level => (
                <div
                  key={level.id}
                  className={`experience-card ${formData.experienceLevel === level.id ? 'selected' : ''}`}
                  onClick={() => handleInputChange('experienceLevel', level.id)}
                >
                  <div className="experience-icon">{level.icon}</div>
                  <h3>{level.title}</h3>
                  <p>{level.desc}</p>
                  <span className="subtext">{level.subtext}</span>
                </div>
              ))}
            </div>
            {errors.experienceLevel && <span className="error-text">{errors.experienceLevel}</span>}
          </div>
        );

      case 5:
        return (
          <div className="onboarding-step">
            <h2>Your workout schedule</h2>
            <p>How often can you commit to working out?</p>
            
            <div className="form-group">
              <label>Days per week: {formData.workoutDaysPerWeek}</label>
              <input
                type="range"
                min="1"
                max="7"
                value={formData.workoutDaysPerWeek}
                onChange={(e) => handleInputChange('workoutDaysPerWeek', parseInt(e.target.value))}
                className="slider"
              />
              <div className="slider-labels">
                <span>1 day</span>
                <span>7 days</span>
              </div>
              {errors.workoutDaysPerWeek && <span className="error-text">{errors.workoutDaysPerWeek}</span>}
            </div>

            <div className="form-group">
              <label>Equipment access</label>
              <div className="equipment-cards">
                {[
                  { id: 'full_gym', icon: '✅', title: 'Full Gym Access', desc: 'I have access to a complete gym' },
                  { id: 'home_gym', icon: '🏠', title: 'Home Gym', desc: 'Limited equipment at home' },
                  { id: 'no_equipment', icon: '🚫', title: 'No Equipment', desc: 'Bodyweight exercises only' }
                ].map(equipment => (
                  <div
                    key={equipment.id}
                    className={`equipment-card ${formData.equipmentAccess === equipment.id ? 'selected' : ''}`}
                    onClick={() => handleInputChange('equipmentAccess', equipment.id)}
                  >
                    <div className="equipment-icon">{equipment.icon}</div>
                    <h4>{equipment.title}</h4>
                    <p>{equipment.desc}</p>
                  </div>
                ))}
              </div>
              {errors.equipmentAccess && <span className="error-text">{errors.equipmentAccess}</span>}
            </div>
          </div>
        );

      default:
        return null;
    }
  };

  if (isSubmitting) {
    return (
      <div className="onboarding-container">
        <div className="onboarding-step success">
          <div className="success-animation">
            <div className="checkmark">✓</div>
            <div className="confetti">🎉</div>
          </div>
          <h1>Setup Complete!</h1>
          <p>Your profile is ready!</p>
          <div className="success-summary">
            <h3>Your Profile Summary:</h3>
            <div className="summary-item">
              <span>Goal:</span>
              <span>{formData.goal.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase())}</span>
            </div>
            <div className="summary-item">
              <span>Experience:</span>
              <span>{formData.experienceLevel.charAt(0).toUpperCase() + formData.experienceLevel.slice(1)}</span>
            </div>
            <div className="summary-item">
              <span>Workouts:</span>
              <span>{formData.workoutDaysPerWeek} days/week</span>
            </div>
          </div>
          <p className="ai-note">💬 Want personalized advice? Try our AI Coach (5 questions/hour, max 20/day)</p>
        </div>
      </div>
    );
  }

  return (
    <div className="onboarding-container">
      <div className="onboarding-header">
        <div className="progress-bar">
          <div 
            className="progress-fill" 
            style={{ width: `${(currentStep / totalSteps) * 100}%` }}
          ></div>
        </div>
        <span className="progress-text">{currentStep} of {totalSteps}</span>
      </div>

      <div className="onboarding-content">
        {renderStep()}
      </div>

      <div className="onboarding-actions">
        {currentStep > 1 && (
          <button onClick={prevStep} className="btn-secondary">
            Back
          </button>
        )}
        
        {currentStep < totalSteps ? (
          <button onClick={nextStep} className="btn-primary">
            Next
          </button>
        ) : (
          <button onClick={handleSubmit} className="btn-primary" disabled={isSubmitting}>
            {isSubmitting ? 'Setting up...' : 'Complete Setup'}
          </button>
        )}
      </div>

      {errors.submit && (
        <div className="error-message">
          {errors.submit}
        </div>
      )}
    </div>
  );
};

export default Onboarding;
