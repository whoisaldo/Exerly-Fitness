import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import API_CONFIG from '../../config';
import {
  GlassCard,
  PageHeader,
  ActionButton,
  ProgressRing,
  EmptyState,
  PageTransition,
} from '../ui';

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

  const goalConfig = {
    dailyCalories: { icon: '🔥', label: 'Daily Calories', unit: 'kcal', color: 'calories', max: 3000 },
    weeklyWorkouts: { icon: '💪', label: 'Weekly Workouts', unit: 'times', color: 'workouts', max: 7 },
    dailySteps: { icon: '👟', label: 'Daily Steps', unit: 'steps', color: 'steps', max: 15000 },
    weeklyWeight: { icon: '⚖️', label: 'Weekly Weight', unit: 'kg', color: 'weight', max: 5 },
    sleepHours: { icon: '😴', label: 'Daily Sleep', unit: 'hours', color: 'sleep', max: 10 },
    waterIntake: { icon: '💧', label: 'Daily Water', unit: 'L', color: 'water', max: 4 }
  };

  const activeGoals = Object.entries(goals).filter(([, value]) => value);
  const hasAnyGoal = activeGoals.length > 0;

  return (
    <PageTransition className="min-h-screen bg-deep px-4 py-6 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-5xl space-y-8">
        {/* Header */}
        <PageHeader
          title="Fitness Goals"
          subtitle="Set and track your fitness objectives"
          action={
            <ActionButton
              variant="ghost"
              onClick={() => navigate('/dashboard')}
              icon={
                <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
                </svg>
              }
            >
              Back
            </ActionButton>
          }
        />

        {/* Goal Cards Grid */}
        <div>
          <h2 className="mb-4 text-lg font-semibold text-slate-100">Your Current Goals</h2>

          {hasAnyGoal ? (
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
              {activeGoals.map(([key, value], i) => {
                const config = goalConfig[key];
                if (!config) return null;
                const pct = Math.min(100, Math.round((Math.abs(parseFloat(value)) / config.max) * 100));

                return (
                  <motion.div
                    key={key}
                    initial={{ opacity: 0, y: 12 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: i * 0.06, duration: 0.35 }}
                  >
                    <GlassCard className="flex items-center gap-5">
                      <ProgressRing value={pct} size={72} strokeWidth={5} label={config.unit} />
                      <div className="min-w-0 flex-1">
                        <p className="text-xs uppercase tracking-wider text-slate-400">{config.label}</p>
                        <p className="mt-1 truncate text-xl font-bold text-slate-50">
                          {value} <span className="text-sm font-normal text-slate-400">{config.unit}</span>
                        </p>
                      </div>
                      <span className="text-2xl">{config.icon}</span>
                    </GlassCard>
                  </motion.div>
                );
              })}

              {/* Add Goal dashed card */}
              <button
                type="button"
                onClick={() => document.getElementById('goals-form')?.scrollIntoView({ behavior: 'smooth' })}
                className="flex min-h-[6rem] items-center justify-center rounded-2xl border-2 border-dashed border-border-subtle text-slate-400 transition-all hover:border-primary/40 hover:bg-primary/5 hover:text-primary-bright"
              >
                <span className="text-2xl mr-2">+</span>
                <span className="text-sm font-medium">Add Goal</span>
              </button>
            </div>
          ) : (
            <GlassCard>
              <EmptyState
                icon={<span className="text-2xl">🎯</span>}
                title="No goals set yet"
                message="Set your first fitness goal below to start tracking your progress."
              />
            </GlassCard>
          )}
        </div>

        {/* Goals Form */}
        <GlassCard id="goals-form" as="section">
          <div className="mb-6">
            <h2 className="text-lg font-semibold text-slate-100">Set Your Goals</h2>
            <p className="mt-1 text-sm text-slate-400">
              Define your targets to stay motivated and track your progress
            </p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-6">
            <div className="grid grid-cols-1 gap-5 md:grid-cols-2 lg:grid-cols-3">
              {Object.entries(goalConfig).map(([key, config]) => (
                <div key={key} className="space-y-1.5">
                  <label className="text-label text-slate-300">
                    <span className="mr-1.5">{config.icon}</span>
                    {config.label}
                  </label>
                  <div className="relative">
                    <input
                      type="number"
                      name={key}
                      value={goals[key]}
                      onChange={handleChange}
                      placeholder={`e.g., ${config.max > 100 ? Math.round(config.max * 0.7) : config.max}`}
                      className="h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 pr-14 text-sm text-slate-100 placeholder-slate-500 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/40"
                      min={key === 'weeklyWeight' ? undefined : '0'}
                      step={key === 'waterIntake' || key === 'sleepHours' || key === 'weeklyWeight' ? '0.1' : '1'}
                      max={key === 'weeklyWorkouts' ? '7' : key === 'sleepHours' ? '24' : undefined}
                    />
                    <span className="pointer-events-none absolute right-4 top-1/2 -translate-y-1/2 text-xs text-slate-500">
                      {config.unit}
                    </span>
                  </div>
                </div>
              ))}
            </div>

            {/* Form Actions */}
            <div className="flex flex-col-reverse gap-3 border-t border-border-subtle pt-5 sm:flex-row sm:justify-end">
              <ActionButton
                type="button"
                variant="secondary"
                onClick={resetGoals}
                disabled={loading}
              >
                Reset
              </ActionButton>
              <ActionButton type="submit" loading={loading} disabled={loading}>
                {loading ? 'Saving...' : 'Save Goals'}
              </ActionButton>
            </div>
          </form>

          {/* Success Message */}
          <AnimatePresence>
            {saved && (
              <motion.div
                initial={{ opacity: 0, y: -8 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -8 }}
                transition={{ duration: 0.3 }}
                className="mt-5 flex items-center gap-2 rounded-xl bg-success/10 border border-success/20 px-4 py-3 text-sm font-medium text-success"
              >
                <svg className="h-4 w-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                </svg>
                Goals saved successfully!
              </motion.div>
            )}
          </AnimatePresence>
        </GlassCard>

        {/* Tips Section */}
        <div>
          <h2 className="mb-4 text-lg font-semibold text-slate-100">Goal Setting Tips</h2>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
            {[
              { icon: '🎯', title: 'Be Specific', desc: 'Set clear, measurable goals instead of vague ones like "get fit"' },
              { icon: '📈', title: 'Start Small', desc: 'Begin with achievable goals and gradually increase difficulty' },
              { icon: '⏰', title: 'Set Deadlines', desc: 'Give yourself realistic timeframes to stay motivated' },
              { icon: '📝', title: 'Track Progress', desc: 'Monitor your achievements to see how far you\'ve come' },
            ].map((tip, i) => (
              <motion.div
                key={tip.title}
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.3 + i * 0.08, duration: 0.35 }}
              >
                <GlassCard className="h-full">
                  <span className="text-2xl">{tip.icon}</span>
                  <h3 className="mt-3 text-sm font-semibold text-slate-100">{tip.title}</h3>
                  <p className="mt-1 text-xs leading-relaxed text-slate-400">{tip.desc}</p>
                </GlassCard>
              </motion.div>
            ))}
          </div>
        </div>
      </div>
    </PageTransition>
  );
}
