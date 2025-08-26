// frontend/src/Components/Dashboard/Profile.jsx
import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import './Profile.css';

const BASE_URL = process.env.REACT_APP_API_URL;

export default function Profile() {
  const navigate = useNavigate();
  const [form, setForm] = useState({
    age: '',
    sex: 'male',
    height_cm: '',
    weight_kg: '',
    activity_level: 'moderate',
    goal: 'maintain',
    target_weight: '',
    target_date: '',
    email_notifications: true,
    privacy_settings: 'public'
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [success, setSuccess] = useState('');
  const [error, setError] = useState('');
  const [useMetric, setUseMetric] = useState(false); // false = American units, true = Metric
  
  // Local display state for inputs
  const [displayValues, setDisplayValues] = useState({
    height: '',
    weight: '',
    targetWeight: ''
  });

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
          setForm(prev => ({
            ...prev,
            age: data.age || '',
            sex: data.sex || 'male',
            height_cm: data.height_cm || '',
            weight_kg: data.weight_kg || '',
            activity_level: data.activity_level || 'moderate',
            goal: data.goal || 'maintain',
            target_weight: data.target_weight || '',
            target_date: data.target_date || '',
            email_notifications: data.email_notifications !== false,
            privacy_settings: data.privacy_settings || 'public'
          }));
          
          // Set display values
          if (data.height_cm) {
            const height = parseFloat(data.height_cm);
            if (!isNaN(height) && height > 0) {
              const displayHeight = useMetric ? height : cmToInches(height);
              setDisplayValues(prev => ({ ...prev, height: displayHeight.toString() }));
            }
          }
          
          if (data.weight_kg) {
            const weight = parseFloat(data.weight_kg);
            if (!isNaN(weight) && weight > 0) {
              const displayWeight = useMetric ? weight : kgToLbs(weight);
              setDisplayValues(prev => ({ ...prev, weight: displayWeight.toString() }));
            }
          }
          
          if (data.target_weight) {
            const targetWeight = parseFloat(data.target_weight);
            if (!isNaN(targetWeight) && targetWeight > 0) {
              const displayTargetWeight = useMetric ? targetWeight : kgToLbs(targetWeight);
              setDisplayValues(prev => ({ ...prev, targetWeight: displayTargetWeight.toString() }));
            }
          }
        }
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [navigate]);



  // Update display values when unit changes
  useEffect(() => {
    if (form.height_cm) {
      const height = parseFloat(form.height_cm);
      if (!isNaN(height) && height > 0) {
        const displayHeight = useMetric ? height : cmToInches(height);
        setDisplayValues(prev => ({ ...prev, height: displayHeight.toString() }));
      }
    }
    
    if (form.weight_kg) {
      const weight = parseFloat(form.weight_kg);
      if (!isNaN(weight) && weight > 0) {
        const displayWeight = useMetric ? weight : kgToLbs(weight);
        setDisplayValues(prev => ({ ...prev, weight: displayWeight.toString() }));
      }
    }
    
    if (form.target_weight) {
      const targetWeight = parseFloat(form.target_weight);
      if (!isNaN(targetWeight) && targetWeight > 0) {
        const displayTargetWeight = useMetric ? targetWeight : kgToLbs(targetWeight);
        setDisplayValues(prev => ({ ...prev, targetWeight: displayTargetWeight.toString() }));
      }
    }
  }, [useMetric, form.height_cm, form.weight_kg, form.target_weight]);


  // Unit conversion functions
  const kgToLbs = (kg) => {
    if (!kg || isNaN(kg)) return '';
    return (parseFloat(kg) * 2.20462).toFixed(1);
  };

  const lbsToKg = (lbs) => {
    if (!lbs || isNaN(lbs)) return '';
    return (parseFloat(lbs) / 2.20462).toFixed(1);
  };

  const cmToInches = (cm) => {
    if (!cm || isNaN(cm)) return '';
    return (parseFloat(cm) / 2.54).toFixed(1);
  };

  const inchesToCm = (inches) => {
    if (!inches || isNaN(inches)) return '';
    return (parseFloat(inches) * 2.54).toFixed(1);
  };

  // Get display values based on current unit preference
  const getDisplayHeight = () => {
    if (!form.height_cm || form.height_cm === '') return '';
    const height = parseFloat(form.height_cm);
    if (isNaN(height) || height <= 0) return '';
    return useMetric ? height : cmToInches(height);
  };

  const getDisplayWeight = () => {
    if (!form.weight_kg || form.weight_kg === '') return '';
    const weight = parseFloat(form.weight_kg);
    if (isNaN(weight) || weight <= 0) return '';
    return useMetric ? weight : kgToLbs(weight);
  };

  const getDisplayTargetWeight = () => {
    if (!form.target_weight || form.target_weight === '') return '';
    const targetWeight = parseFloat(form.target_weight);
    if (isNaN(targetWeight) || targetWeight <= 0) return '';
    return useMetric ? targetWeight : kgToLbs(targetWeight);
  };

  // Handle height input changes
  const handleHeightChange = (e) => {
    const value = e.target.value;
    setDisplayValues(prev => ({ ...prev, height: value }));
  };

  // Handle weight input changes
  const handleWeightChange = (e) => {
    const value = e.target.value;
    setDisplayValues(prev => ({ ...prev, weight: value }));
  };

  // Handle target weight input changes
  const handleTargetWeightChange = (e) => {
    const value = e.target.value;
    setDisplayValues(prev => ({ ...prev, targetWeight: value }));
  };

  // Handle height input blur (convert and store)
  const handleHeightBlur = () => {
    const value = displayValues.height;
    if (!value || value === '') {
      setForm(prev => ({ ...prev, height_cm: '' }));
      return;
    }
    
    const numValue = parseFloat(value);
    if (isNaN(numValue) || numValue <= 0) return;
    
    // Convert to cm for storage
    const heightCm = useMetric ? numValue : inchesToCm(numValue);
    setForm(prev => ({ ...prev, height_cm: heightCm.toString() }));
  };

  // Handle weight input blur (convert and store)
  const handleWeightBlur = () => {
    const value = displayValues.weight;
    if (!value || value === '') {
      setForm(prev => ({ ...prev, weight_kg: '' }));
      return;
    }
    
    const numValue = parseFloat(value);
    if (isNaN(numValue) || numValue <= 0) return;
    
    // Convert to kg for storage
    const weightKg = useMetric ? numValue : lbsToKg(numValue);
    setForm(prev => ({ ...prev, weight_kg: weightKg.toString() }));
  };

  // Handle target weight input blur (convert and store)
  const handleTargetWeightBlur = () => {
    const value = displayValues.targetWeight;
    if (!value || value === '') {
      setForm(prev => ({ ...prev, target_weight: '' }));
      return;
    }
    
    const numValue = parseFloat(value);
    if (isNaN(numValue) || numValue <= 0) return;
    
    // Convert to kg for storage
    const targetWeightKg = useMetric ? numValue : lbsToKg(numValue);
    setForm(prev => ({ ...prev, target_weight: targetWeightKg.toString() }));
  };

  // Handle regular form changes for non-converting fields
  const handleChange = e => {
    const { name, value, type, checked } = e.target;
    
    // Skip the converting fields as they have their own handlers
    if (['height_cm', 'weight_kg', 'target_weight'].includes(name)) {
      return;
    }
    
    if (type === 'checkbox') {
      setForm(prev => ({ ...prev, [name]: checked }));
    } else {
      setForm(prev => ({ ...prev, [name]: value }));
    }
  };

  // Handle unit toggle
  const handleUnitToggle = () => {
    setUseMetric(!useMetric);
  };

  const handleSubmit = async e => {
    e.preventDefault();
    const token = localStorage.getItem('token');
    if (!token) return navigate('/');
    
    setSaving(true);
    setError('');
    setSuccess('');
    
    try {
      // Validate required fields
      if (!form.age || !form.height_cm || !form.weight_kg) {
        setError('Please fill in all required fields (Age, Height, Weight)');
        setSaving(false);
        return;
      }

      const res = await fetch(`${BASE_URL}/api/profile`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer ' + token,
        },
        body: JSON.stringify(form),
      });
      
      if (res.ok) {
        const result = await res.json();
        setSuccess('Profile updated successfully!');
        setTimeout(() => setSuccess(''), 3000);
      } else {
        const errorText = await res.text();
        setError(`Failed to save profile: ${errorText}`);
      }
    } catch (err) {
      setError('Failed to save profile. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  const calculateBMI = () => {
    if (!form.height_cm || !form.weight_kg) return null;
    const height = parseFloat(form.height_cm);
    const weight = parseFloat(form.weight_kg);
    
    if (isNaN(height) || isNaN(weight) || height <= 0 || weight <= 0) return null;
    
    const heightM = height / 100;
    const bmi = weight / (heightM * heightM);
    return bmi.toFixed(1);
  };

  const getBMICategory = (bmi) => {
    if (bmi < 18.5) return { category: 'Underweight', color: 'warning' };
    if (bmi < 25) return { category: 'Normal', color: 'success' };
    if (bmi < 30) return { category: 'Overweight', color: 'warning' };
    return { category: 'Obese', color: 'error' };
  };

  const getActivityLevelDescription = (level) => {
    const descriptions = {
      sedentary: 'Little to no exercise',
      light: 'Light exercise 1-3 days/week',
      moderate: 'Moderate exercise 3-5 days/week',
      active: 'Hard exercise 6-7 days/week',
      'very active': 'Very hard exercise, physical job'
    };
    return descriptions[level] || '';
  };

  if (loading) {
    return (
      <div className="profile-page">
        <div className="loading-state">
          <div className="spinner"></div>
          <p>Loading profile...</p>
        </div>
      </div>
    );
  }

  const bmi = calculateBMI();
  const bmiInfo = bmi ? getBMICategory(bmi) : null;

  return (
    <div className="profile-page">
      {/* Header */}
      <div className="profile-header">
        <button className="back-btn" onClick={() => navigate('/dashboard')}>
          Back to Dashboard
        </button>
        <div className="header-content">
          <h1 className="profile-title">Your Profile</h1>
          <p className="profile-subtitle">Manage your personal information and fitness goals</p>
        </div>
      </div>

      {/* Success/Error Messages */}
      {success && (
        <div className="message-banner success">
          <span>{success}</span>
        </div>
      )}
      {error && (
        <div className="message-banner error">
          <span>{error}</span>
          <button onClick={() => setError('')}>×</button>
        </div>
      )}

      <div className="profile-content">
        {/* Unit Toggle */}
        <div className="unit-toggle-section">
          <div className="unit-toggle">
            <span className={`unit-option ${!useMetric ? 'active' : ''}`}>
              Imperial (lbs, inches)
            </span>
            <button 
              className="toggle-switch"
              onClick={handleUnitToggle}
              aria-label="Toggle units"
            >
              <span className={`toggle-slider ${useMetric ? 'metric' : 'imperial'}`}></span>
            </button>
            <span className={`unit-option ${useMetric ? 'active' : ''}`}>
              Metric (kg, cm)
            </span>
          </div>
        </div>

        {/* Profile Overview Card */}
        <div className="profile-overview">
          <div className="overview-header">
            <h2>Profile Overview</h2>
            <div className="overview-avatar">
              <span>{form.name ? form.name.charAt(0).toUpperCase() : 'U'}</span>
            </div>
          </div>
          
          {bmi && (
            <div className="bmi-section">
              <div className="bmi-value">
                <span className="bmi-number">{bmi}</span>
                <span className="bmi-label">BMI</span>
              </div>
              <div className={`bmi-category ${bmiInfo.color}`}>
                {bmiInfo.category}
              </div>
            </div>
          )}

          <div className="overview-stats">
            <div className="stat-item">
              <span className="stat-value">{form.age || '--'}</span>
              <span className="stat-label">Age</span>
            </div>
            <div className="stat-item">
              <span className="stat-value">
                {getDisplayHeight() || '--'} {useMetric ? 'cm' : 'inches'}
              </span>
              <span className="stat-label">Height</span>
            </div>
            <div className="stat-item">
              <span className="stat-value">
                {getDisplayWeight() || '--'} {useMetric ? 'kg' : 'lbs'}
              </span>
              <span className="stat-label">Weight</span>
            </div>
          </div>
        </div>

        {/* Profile Form */}
        <form onSubmit={handleSubmit} className="profile-form-section">
          <div className="section-header">
            <h2>Personal Information</h2>
            <p>Update your basic profile details</p>
          </div>
          
          <div className="form-grid">
            <div className="form-group">
              <label className="form-label">
                <span className="label-icon">👤</span>
                Age *
              </label>
              <input
                key={`age-${useMetric}`}
                name="age"
                type="number"
                placeholder="Enter your age"
                value={form.age}
                onChange={handleChange}
                min="13"
                max="120"
                required
                className="form-input"
              />
            </div>

            <div className="form-group">
              <label className="form-label">
                <span className="label-icon">⚧</span>
                Sex
              </label>
              <select 
                name="sex" 
                value={form.sex} 
                onChange={handleChange}
                className="form-select"
              >
                <option value="male">Male</option>
                <option value="female">Female</option>
                <option value="other">Other</option>
              </select>
            </div>

            <div className="form-group">
              <label className="form-label">
                <span className="label-icon">📏</span>
                Height ({useMetric ? 'cm' : 'inches'}) *
              </label>
              <input
                key={`height-${useMetric}`}
                name="height_cm"
                type="number"
                placeholder={`Enter height in ${useMetric ? 'cm' : 'inches'}`}
                value={displayValues.height}
                onChange={handleHeightChange}
                onBlur={handleHeightBlur}
                min={useMetric ? 100 : 40}
                max={useMetric ? 250 : 100}
                required
                className="form-input"
              />
              <p className="form-help">
                {useMetric ? 'Centimeters (100-250 cm)' : 'Inches (40-100 inches)'}
              </p>
            </div>

            <div className="form-group">
              <label className="form-label">
                <span className="label-icon">⚖️</span>
                Weight ({useMetric ? 'kg' : 'lbs'}) *
              </label>
              <input
                key={`weight-${useMetric}`}
                name="weight_kg"
                type="number"
                placeholder={`Enter weight in ${useMetric ? 'kg' : 'lbs'}`}
                value={displayValues.weight}
                onChange={handleWeightChange}
                onBlur={handleWeightBlur}
                min={useMetric ? 30 : 66}
                max={useMetric ? 300 : 661}
                required
                className="form-input"
              />
              <p className="form-help">
                {useMetric ? 'Kilograms (30-300 kg)' : 'Pounds (66-661 lbs)'}
              </p>
            </div>
          </div>

          <div className="section-header">
            <h2>Activity & Goals</h2>
            <p>Set your fitness activity level and goals</p>
          </div>

          <div className="form-grid">
            <div className="form-group">
              <label className="form-label">
                <span className="label-icon">🏃‍♂️</span>
                Activity Level
              </label>
              <select
                name="activity_level"
                value={form.activity_level}
                onChange={handleChange}
                className="form-select"
              >
                <option value="sedentary">Sedentary</option>
                <option value="light">Light</option>
                <option value="moderate">Moderate</option>
                <option value="active">Active</option>
                <option value="very active">Very Active</option>
              </select>
              <p className="form-help">{getActivityLevelDescription(form.activity_level)}</p>
            </div>

            <div className="form-group">
              <label className="form-label">
                <span className="label-icon">🎯</span>
                Fitness Goal
              </label>
              <select
                name="goal"
                value={form.goal}
                onChange={handleChange}
                className="form-select"
              >
                <option value="lose">Lose Weight</option>
                <option value="maintain">Maintain Weight</option>
                <option value="gain">Gain Weight</option>
                <option value="build_muscle">Build Muscle</option>
              </select>
            </div>

            <div className="form-group">
              <label className="form-label">
                <span className="label-icon">🎯</span>
                Target Weight ({useMetric ? 'kg' : 'lbs'})
              </label>
              <input
                key={`target-weight-${useMetric}`}
                name="target_weight"
                type="number"
                placeholder={`Enter target weight in ${useMetric ? 'kg' : 'lbs'}`}
                value={displayValues.targetWeight}
                onChange={handleTargetWeightChange}
                onBlur={handleTargetWeightBlur}
                min={useMetric ? 30 : 66}
                max={useMetric ? 300 : 661}
                className="form-input"
              />
              <p className="form-help">
                {useMetric ? 'Kilograms (30-300 kg)' : 'Pounds (66-661 lbs)'}
              </p>
            </div>

            <div className="form-group">
              <label className="form-label">
                <span className="label-icon">📅</span>
                Target Date
              </label>
              <input
                name="target_date"
                type="date"
                value={form.target_date}
                onChange={handleChange}
                className="form-input"
              />
            </div>
          </div>

          <div className="section-header">
            <h2>Preferences</h2>
            <p>Customize your app experience</p>
          </div>

          <div className="form-grid">
            <div className="form-group checkbox-group">
              <label className="checkbox-label">
                <input
                  name="email_notifications"
                  type="checkbox"
                  checked={form.email_notifications}
                  onChange={handleChange}
                  className="form-checkbox"
                />
                <span className="checkbox-text">Receive email notifications</span>
              </label>
            </div>

            <div className="form-group">
              <label className="form-label">
                <span className="label-icon">🔒</span>
                Privacy Settings
              </label>
              <select
                name="privacy_settings"
                value={form.privacy_settings}
                onChange={handleChange}
                className="form-select"
              >
                <option value="public">Public Profile</option>
                <option value="friends">Friends Only</option>
                <option value="private">Private</option>
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
                  <div className="spinner"></div>
                  Saving...
                </>
              ) : (
                'Save Profile'
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
