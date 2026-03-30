import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import user_icon     from '../Assets/person.png';
import email_icon    from '../Assets/email.png';
import password_icon from '../Assets/password.png';
import exerly_logo   from '../Assets/ExerlyLogo.jpg';
import { useNavigate, Link } from 'react-router-dom';
import API_CONFIG from '../../config';
import { GlassCard, ActionButton } from '../ui';

const BASE_URL = API_CONFIG.BASE_URL;

const LoginSignup = () => {
  const [action, setAction] = useState('Sign Up');
  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [showPassword, setShowPassword] = useState(false);
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

  const tabs = ['Login', 'Sign Up'];

  return (
    <div className="min-h-screen bg-deep flex items-center justify-center relative overflow-hidden px-4 py-8">
      {/* Animated background orbs */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <motion.div
          className="absolute top-[-20%] right-[-15%] w-[500px] h-[500px] rounded-full opacity-20"
          style={{ background: 'radial-gradient(circle, #8b5cf6 0%, transparent 70%)' }}
          animate={{ x: [0, 30, 0], y: [0, -40, 0] }}
          transition={{ duration: 8, repeat: Infinity, ease: 'easeInOut' }}
        />
        <motion.div
          className="absolute bottom-[-15%] left-[-10%] w-[450px] h-[450px] rounded-full opacity-15"
          style={{ background: 'radial-gradient(circle, #ec4899 0%, transparent 70%)' }}
          animate={{ x: [0, -20, 0], y: [0, 30, 0] }}
          transition={{ duration: 10, repeat: Infinity, ease: 'easeInOut' }}
        />
        <motion.div
          className="absolute top-[30%] left-[40%] w-[300px] h-[300px] rounded-full opacity-10"
          style={{ background: 'radial-gradient(circle, #8b5cf6 0%, transparent 70%)' }}
          animate={{ x: [0, -15, 0], y: [0, 15, 0] }}
          transition={{ duration: 12, repeat: Infinity, ease: 'easeInOut' }}
        />
      </div>

      {/* Back link */}
      <Link
        to="/"
        className="absolute top-5 left-5 z-20 text-sm text-slate-500 hover:text-white transition-colors"
      >
        &larr; Back to Landing Page
      </Link>

      {/* Main layout */}
      <div className="relative z-10 w-full max-w-5xl grid lg:grid-cols-2 gap-0 lg:gap-8 items-center">
        {/* Left side - Form */}
        <motion.div
          initial={{ opacity: 0, x: -24 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
        >
          <GlassCard elevated className="rounded-2xl p-6 sm:p-8 max-w-md mx-auto lg:max-w-none w-full">
            {/* Logo */}
            <div className="text-center mb-6">
              <img
                src={exerly_logo}
                alt="Exerly Logo"
                className="w-14 h-14 rounded-xl object-cover mx-auto mb-3 shadow-glow-sm"
              />
              <h1 className="text-xl font-bold text-white">Exerly</h1>
              <p className="text-sm text-slate-500 mt-0.5">Transform Your Fitness Journey</p>
            </div>

            {/* Tab toggle */}
            <div className="relative flex bg-surface-2 rounded-xl p-1 mb-6">
              {tabs.map((tab) => (
                <button
                  key={tab}
                  type="button"
                  onClick={() => setAction(tab)}
                  className={`relative z-10 flex-1 py-2.5 text-sm font-medium rounded-lg transition-colors min-h-11 ${
                    action === tab ? 'text-white' : 'text-slate-500 hover:text-slate-300'
                  }`}
                >
                  {tab === 'Sign Up' ? 'Create Account' : 'Welcome Back'}
                  {action === tab && (
                    <motion.div
                      layoutId="auth-tab-indicator"
                      className="absolute inset-0 bg-gradient-primary rounded-lg -z-10"
                      transition={{ type: 'spring', stiffness: 380, damping: 30 }}
                    />
                  )}
                </button>
              ))}
            </div>

            {/* Subtitle */}
            <p className="text-sm text-slate-400 text-center mb-5">
              {action === 'Sign Up'
                ? 'Join Exerly and start tracking your fitness goals'
                : 'Sign in to continue your fitness journey'}
            </p>

            {/* Messages */}
            <AnimatePresence mode="wait">
              {error && (
                <motion.div
                  key="error"
                  initial={{ opacity: 0, y: -8, x: 0 }}
                  animate={{ opacity: 1, y: 0, x: [0, -6, 6, -4, 4, 0] }}
                  exit={{ opacity: 0, y: -8 }}
                  transition={{ duration: 0.4 }}
                  className="mb-4 rounded-xl bg-error/10 border border-error/20 px-4 py-3 text-sm text-error"
                >
                  {error}
                </motion.div>
              )}
              {success && (
                <motion.div
                  key="success"
                  initial={{ opacity: 0, y: -8 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -8 }}
                  className="mb-4 rounded-xl bg-success/10 border border-success/20 px-4 py-3 text-sm text-success"
                >
                  {success}
                </motion.div>
              )}
            </AnimatePresence>

            {/* Form */}
            <form onSubmit={handleSubmit} className="space-y-4">
              <AnimatePresence mode="wait">
                {action === 'Sign Up' && (
                  <motion.div
                    key="username-field"
                    initial={{ opacity: 0, height: 0 }}
                    animate={{ opacity: 1, height: 'auto' }}
                    exit={{ opacity: 0, height: 0 }}
                    transition={{ duration: 0.25 }}
                    className="overflow-hidden"
                  >
                    <div className="relative">
                      <div className="absolute left-3.5 top-1/2 -translate-y-1/2 w-5 h-5 flex items-center justify-center opacity-50">
                        <img src={user_icon} alt="User" className="w-4 h-4" />
                      </div>
                      <input
                        type="text"
                        placeholder="Full Name"
                        value={username}
                        onChange={e => setUsername(e.target.value)}
                        className="w-full min-h-11 bg-surface-2 border border-border-subtle rounded-xl pl-11 pr-4 py-3 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary/30 transition-colors"
                        required
                      />
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>

              <div className="relative">
                <div className="absolute left-3.5 top-1/2 -translate-y-1/2 w-5 h-5 flex items-center justify-center opacity-50">
                  <img src={email_icon} alt="Email" className="w-4 h-4" />
                </div>
                <input
                  type="email"
                  placeholder="Email Address"
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                  className="w-full min-h-11 bg-surface-2 border border-border-subtle rounded-xl pl-11 pr-4 py-3 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary/30 transition-colors"
                  required
                />
              </div>

              <div className="relative">
                <div className="absolute left-3.5 top-1/2 -translate-y-1/2 w-5 h-5 flex items-center justify-center opacity-50">
                  <img src={password_icon} alt="Password" className="w-4 h-4" />
                </div>
                <input
                  type={showPassword ? 'text' : 'password'}
                  placeholder="Password"
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  className="w-full min-h-11 bg-surface-2 border border-border-subtle rounded-xl pl-11 pr-11 py-3 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary/30 transition-colors"
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(prev => !prev)}
                  className="absolute right-3.5 top-1/2 -translate-y-1/2 text-slate-500 hover:text-slate-300 transition-colors p-0 bg-transparent border-none cursor-pointer"
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                >
                  {showPassword ? (
                    <svg className="w-4.5 h-4.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5} width="18" height="18">
                      <path strokeLinecap="round" strokeLinejoin="round" d="M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88" />
                    </svg>
                  ) : (
                    <svg className="w-4.5 h-4.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5} width="18" height="18">
                      <path strokeLinecap="round" strokeLinejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" />
                      <path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    </svg>
                  )}
                </button>
              </div>

              {/* Forgot password */}
              {action === 'Login' && (
                <div className="text-right">
                  <span className="text-xs text-primary-bright hover:text-primary cursor-pointer transition-colors">
                    Forgot Password?
                  </span>
                </div>
              )}

              {/* Submit */}
              <ActionButton
                type="submit"
                variant="primary"
                loading={loading}
                className="w-full min-h-12 text-sm font-semibold"
              >
                {action}
              </ActionButton>
            </form>

            {/* Switch mode */}
            <div className="mt-6 text-center text-sm">
              <span className="text-slate-500">
                {action === 'Login' ? "Don't have an account?" : "Already have an account?"}
              </span>{' '}
              <button
                type="button"
                onClick={() => setAction(action === 'Login' ? 'Sign Up' : 'Login')}
                className="text-primary-bright hover:text-primary font-medium transition-colors bg-transparent border-none cursor-pointer p-0"
              >
                {action === 'Login' ? 'Sign Up' : 'Login'}
              </button>
            </div>
          </GlassCard>
        </motion.div>

        {/* Right side - Visual (hidden on mobile) */}
        <motion.div
          initial={{ opacity: 0, x: 24 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ duration: 0.5, delay: 0.15, ease: [0.16, 1, 0.3, 1] }}
          className="hidden lg:flex flex-col items-center justify-center text-center"
        >
          <div className="relative w-full max-w-sm">
            {/* Decorative floating orbs */}
            <motion.div
              className="absolute -top-12 -left-8 w-24 h-24 rounded-full opacity-30"
              style={{ background: 'radial-gradient(circle, #8b5cf6 0%, transparent 70%)' }}
              animate={{ y: [0, -12, 0] }}
              transition={{ duration: 4, repeat: Infinity, ease: 'easeInOut' }}
            />
            <motion.div
              className="absolute -bottom-8 -right-6 w-20 h-20 rounded-full opacity-25"
              style={{ background: 'radial-gradient(circle, #ec4899 0%, transparent 70%)' }}
              animate={{ y: [0, 10, 0] }}
              transition={{ duration: 5, repeat: Infinity, ease: 'easeInOut' }}
            />

            <GlassCard className="rounded-2xl py-12">
              <motion.div
                animate={{ y: [0, -8, 0] }}
                transition={{ duration: 5, repeat: Infinity, ease: 'easeInOut' }}
              >
                <img
                  src={exerly_logo}
                  alt="Exerly"
                  className="w-24 h-24 rounded-2xl object-cover mx-auto mb-6 shadow-glow-primary"
                />
              </motion.div>
              <h2 className="text-2xl font-bold bg-gradient-primary bg-clip-text text-transparent mb-2">
                Your Fitness, Elevated
              </h2>
              <p className="text-slate-400 text-sm max-w-xs mx-auto leading-relaxed">
                Track workouts, monitor nutrition, and achieve your goals with intelligent analytics.
              </p>
              <div className="flex justify-center gap-6 mt-8">
                {[
                  { val: '1.2K+', lbl: 'Users' },
                  { val: '15K+', lbl: 'Activities' },
                  { val: '8.9K+', lbl: 'Meals' },
                ].map((s) => (
                  <div key={s.lbl} className="text-center">
                    <div className="text-lg font-bold text-primary-bright">{s.val}</div>
                    <div className="text-xs text-slate-500">{s.lbl}</div>
                  </div>
                ))}
              </div>
            </GlassCard>
          </div>
        </motion.div>
      </div>

      {/* Bottom nav links */}
      <div className="absolute bottom-5 left-0 right-0 flex justify-center items-center gap-3 text-xs text-slate-600 z-10">
        <Link to="/credits" className="hover:text-slate-400 transition-colors">Credits</Link>
        <span>&bull;</span>
        <span className="hover:text-slate-400 cursor-pointer transition-colors">About</span>
        <span>&bull;</span>
        <span className="hover:text-slate-400 cursor-pointer transition-colors">Help</span>
      </div>
    </div>
  );
};

export default LoginSignup;
