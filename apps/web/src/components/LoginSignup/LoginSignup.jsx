import React, { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useNavigate, Link } from 'react-router-dom';
import API_CONFIG from '../../config';
import { saveSession, getSessionScope, getAuthGeneration } from '../../lib/sessionStorage';
import { browserTimezone } from '../../lib/api';
import { GlassCard, ActionButton, ExerlyMark, PulseLine } from '../ui';

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
  const requestRef = useRef(null);
  useEffect(() => () => requestRef.current?.abort(), []);

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
    if (action === 'Sign Up' && password.length < 8) {
      setError('Password must be at least 8 characters');
      return false;
    }
    return true;
  };

  const handleSubmit = async (event) => {
    event.preventDefault();
    if (requestRef.current || !validateForm()) return;
    const scope = getSessionScope();
    const generation = getAuthGeneration();
    const location = window.location.href;
    const controller = new AbortController();
    requestRef.current = controller;
    const timeout = window.setTimeout(() => controller.abort(), 15000);
    setLoading(true);
    setError('');
    try {
      const res = await fetch(`${BASE_URL}${action === 'Sign Up' ? '/signup' : '/login'}`, {
        method: 'POST',
        signal: controller.signal,
        headers: {
          'Content-Type': 'application/json',
          'X-Session-Protocol': '2',
          'X-Device-Name': 'Exerly web',
        },
        body: JSON.stringify({ name: username, email, password, timezone: browserTimezone() }),
      });
      const data = await res.json().catch(() => ({}));
      if (controller.signal.aborted || window.location.href !== location) return;
      if (getSessionScope() !== scope || getAuthGeneration() !== generation) {
        setError('Your session changed in another tab. Submit again to sign in to this account.');
        return;
      }
      if (!res.ok) {
        setError(data.message || 'Could not sign in. Try again.');
        return;
      }
      saveSession(data);
      navigate(data.user?.onboardingCompleted ? '/dashboard' : '/onboarding');
    } catch (err) {
      setError(
        controller.signal.aborted
          ? 'Sign-in took too long. Please try again.'
          : err instanceof TypeError
            ? 'Could not connect. Check your connection and try again.'
            : err.message || 'Could not sign in. Try again.'
      );
    } finally {
      window.clearTimeout(timeout);
      requestRef.current = null;
      setLoading(false);
    }
  };

  const tabs = ['Login', 'Sign Up'];

  return (
    <div className="min-h-dvh bg-deep flex items-center justify-center relative overflow-hidden px-4 py-8">
      {/* Quiet backdrop: soft top wash + signature pulse line */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none" aria-hidden="true">
        <div className="absolute inset-x-0 top-0 h-64 bg-gradient-to-b from-surface-1/70 to-transparent" />
        <PulseLine
          className="absolute left-1/2 top-14 h-8 w-80 -translate-x-1/2 text-primary/25"
          strokeWidth={1.5}
        />
      </div>

      {/* Back link */}
      <Link
        to="/"
        onClick={() => requestRef.current?.abort()}
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
          <GlassCard
            elevated
            className="rounded-2xl p-6 sm:p-8 max-w-md mx-auto lg:max-w-none w-full"
          >
            {/* Logo */}
            <div className="text-center mb-6">
              <ExerlyMark size={48} withWordmark={false} className="mb-3" />
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
                  disabled={loading}
                  aria-pressed={action === tab}
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
                <div
                  key="error"
                  id="auth-error"
                  role="alert"
                  className="mb-4 rounded-xl bg-red-950/30 border border-red-400/30 px-4 py-3 text-sm text-red-300"
                >
                  {error}
                </div>
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
              {action === 'Sign Up' && (
                <motion.div
                  key="username-field"
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: 'auto' }}
                  transition={{ duration: 0.25 }}
                  className="overflow-hidden"
                >
                  <div className="relative">
                    <label htmlFor="auth-name" className="mb-1.5 block text-sm text-slate-300">
                      Full name
                    </label>
                    <input
                      type="text"
                      id="auth-name"
                      autoComplete="name"
                      aria-describedby={error ? 'auth-error' : undefined}
                      maxLength={80}
                      placeholder="Full Name"
                      value={username}
                      onChange={(e) => setUsername(e.target.value)}
                      className="w-full min-h-11 bg-surface-2 border border-border-subtle rounded-xl px-4 py-3 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary/30 transition-colors"
                      required
                    />
                  </div>
                </motion.div>
              )}

              <div className="relative">
                <label htmlFor="auth-email" className="mb-1.5 block text-sm text-slate-300">
                  Email address
                </label>
                <input
                  type="email"
                  id="auth-email"
                  autoComplete="email"
                  aria-describedby={error ? 'auth-error' : undefined}
                  maxLength={254}
                  placeholder="Email Address"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="w-full min-h-11 bg-surface-2 border border-border-subtle rounded-xl px-4 py-3 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary/30 transition-colors"
                  required
                />
              </div>

              <div className="relative">
                <label htmlFor="auth-password" className="mb-1.5 block text-sm text-slate-300">
                  Password
                </label>
                <input
                  id="auth-password"
                  autoComplete={action === 'Sign Up' ? 'new-password' : 'current-password'}
                  aria-describedby={error ? 'auth-error' : undefined}
                  minLength={action === 'Sign Up' ? 8 : undefined}
                  maxLength={200}
                  type={showPassword ? 'text' : 'password'}
                  placeholder="Password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="w-full min-h-11 bg-surface-2 border border-border-subtle rounded-xl pl-4 pr-12 py-3 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary/30 transition-colors"
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((prev) => !prev)}
                  className="absolute bottom-0 right-0 flex size-11 items-center justify-center text-slate-300 hover:text-slate-300 transition-colors p-0 bg-transparent border-none cursor-pointer"
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                >
                  {showPassword ? (
                    <svg
                      className="w-4.5 h-4.5"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      strokeWidth={1.5}
                      width="18"
                      height="18"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        d="M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88"
                      />
                    </svg>
                  ) : (
                    <svg
                      className="w-4.5 h-4.5"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      strokeWidth={1.5}
                      width="18"
                      height="18"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z"
                      />
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                      />
                    </svg>
                  )}
                </button>
              </div>

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
                {action === 'Login' ? "Don't have an account?" : 'Already have an account?'}
              </span>{' '}
              <button
                type="button"
                onClick={() => setAction(action === 'Login' ? 'Sign Up' : 'Login')}
                disabled={loading}
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
            <GlassCard className="rounded-2xl py-12">
              <motion.div
                animate={{ y: [0, -8, 0] }}
                transition={{ duration: 5, repeat: Infinity, ease: 'easeInOut' }}
              >
                <ExerlyMark size={96} withWordmark={false} className="mb-6" />
              </motion.div>
              <h2 className="text-2xl font-bold text-slate-50 mb-2">Your Fitness, Elevated</h2>
              <p className="text-slate-400 text-sm max-w-xs mx-auto leading-relaxed">
                Track workouts, monitor nutrition, and achieve your goals with intelligent
                analytics.
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
        <Link to="/credits" className="hover:text-slate-400 transition-colors">
          Credits
        </Link>
        <span>&bull;</span>
        <span className="hover:text-slate-400 cursor-pointer transition-colors">About</span>
        <span>&bull;</span>
        <span className="hover:text-slate-400 cursor-pointer transition-colors">Help</span>
      </div>
    </div>
  );
};

export default LoginSignup;
