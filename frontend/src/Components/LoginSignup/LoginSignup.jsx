import React, { useState, useEffect } from 'react';
import './LoginSignup.css';
import user_icon     from '../Assets/person.png';
import email_icon    from '../Assets/email.png';
import password_icon from '../Assets/password.png';
import exerly_logo   from '../Assets/ExerlyLogo.jpg';
import { useNavigate, Link } from 'react-router-dom';
import API_CONFIG from '../../config';

const BASE_URL = API_CONFIG.BASE_URL;

const LoginSignup = () => {
  const [action, setAction] = useState('Sign Up');
  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const navigate = useNavigate();

  // Clear messages when switching modes
  useEffect(() => {
    setError('');
    setSuccess('');
  }, [action]);

  const validateForm = () => {
    if (!email || !password) {
      setError('Please fill in all required fields');
      return false;
    }
    if (action === 'Sign Up' && !username.trim()) {
      setError('Please enter your full name');
      return false;
    }
    if (password.length < 6) {
      setError('Password must be at least 6 characters');
      return false;
    }
    return true;
  };

  const handleSignup = async () => {
    if (!validateForm()) return;
    
    setLoading(true);
    setError('');
    try {
      const res = await fetch(`${BASE_URL}/signup`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: username, email, password })
      });
      const data = await res.json();
      
      if (res.ok) {
        setSuccess('Account created successfully! Please log in.');
        setAction('Login');
        setUsername('');
        setPassword('');
      } else {
        setError(data.message || 'Signup failed');
      }
    } catch (err) {
      setError('Network error. Please try again.');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleLogin = async () => {
    if (!validateForm()) return;
    
    setLoading(true);
    setError('');
    try {
      const res = await fetch(`${BASE_URL}/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      });
      const data = await res.json();
      
      if (data.token) {
        localStorage.setItem('token', data.token);
        setSuccess('Login successful! Redirecting...');
        setTimeout(() => navigate('/dashboard'), 1000);
      } else {
        setError(data.message || 'Login failed');
      }
    } catch (err) {
      setError('Network error. Please try again.');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    if (action === 'Sign Up') {
      handleSignup();
    } else {
      handleLogin();
    }
  };

  return (
    <div className="auth-container">
      {/* Background Elements */}
      <div className="bg-circles">
        <div className="circle circle-1"></div>
        <div className="circle circle-2"></div>
        <div className="circle circle-3"></div>
      </div>

      {/* Back Button */}
      <Link to="/" className="back-to-landing">
        ← Back to Landing Page
      </Link>

      {/* Main Content */}
      <div className="auth-card">
        {/* Logo Section */}
        <div className="logo-section">
          <div className="logo-wrapper">
            <img src={exerly_logo} alt="Exerly Logo" className="exerly-logo" />
          </div>
          <h1 className="brand-name">Exerly</h1>
          <p className="brand-tagline">Transform Your Fitness Journey</p>
        </div>

        {/* Form Section */}
        <div className="form-section">
          <div className="form-header">
            <h2 className="form-title">
              {action === 'Sign Up' ? 'Create Account' : 'Welcome Back'}
            </h2>
            <p className="form-subtitle">
              {action === 'Sign Up' 
                ? 'Join Exerly and start tracking your fitness goals' 
                : 'Sign in to continue your fitness journey'
              }
            </p>
          </div>

          {/* Messages */}
          {error && <div className="message error">{error}</div>}
          {success && <div className="message success">{success}</div>}

          {/* Form */}
          <form onSubmit={handleSubmit} className="auth-form">
            {action === 'Sign Up' && (
              <div className="input-group">
                <div className="input-icon">
                  <img src={user_icon} alt="User" />
                </div>
                <input
                  type="text"
                  placeholder="Full Name"
                  value={username}
                  onChange={e => setUsername(e.target.value)}
                  className="auth-input"
                  required
                />
              </div>
            )}

            <div className="input-group">
              <div className="input-icon">
                <img src={email_icon} alt="Email" />
              </div>
              <input
                type="email"
                placeholder="Email Address"
                value={email}
                onChange={e => setEmail(e.target.value)}
                className="auth-input"
                required
              />
            </div>

            <div className="input-group">
              <div className="input-icon">
                <img src={password_icon} alt="Password" />
              </div>
              <input
                type="password"
                placeholder="Password"
                value={password}
                onChange={e => setPassword(e.target.value)}
                className="auth-input"
                required
              />
            </div>

            {/* Forgot Password */}
            {action === 'Login' && (
              <div className="forgot-password">
                <span className="forgot-link">Forgot Password?</span>
              </div>
            )}

            {/* Submit Button */}
            <button
              type="submit"
              className={`submit-btn ${loading ? 'loading' : ''}`}
              disabled={loading}
            >
              {loading ? (
                <div className="spinner"></div>
              ) : (
                action
              )}
            </button>
          </form>

          {/* Switch Mode */}
          <div className="switch-mode">
            <span className="switch-text">
              {action === 'Login' ? "Don't have an account?" : "Already have an account?"}
            </span>
            <button
              type="button"
              className="switch-btn"
              onClick={() => setAction(action === 'Login' ? 'Sign Up' : 'Login')}
            >
              {action === 'Login' ? 'Sign Up' : 'Login'}
            </button>
          </div>
        </div>
      </div>

      {/* Navigation Links */}
      <div className="nav-links">
        <Link to="/credits" className="nav-link">Credits</Link>
        <span className="nav-separator">•</span>
        <span className="nav-link">About</span>
        <span className="nav-separator">•</span>
        <span className="nav-link">Help</span>
      </div>
    </div>
  );
};

export default LoginSignup;
