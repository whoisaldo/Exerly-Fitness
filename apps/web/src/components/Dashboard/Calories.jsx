import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import API_CONFIG from '../../config';
import {
  GlassCard,
  PageHeader,
  ActionButton,
  Badge,
  ProgressRing,
  EmptyState,
  LoadingSkeleton,
  PageTransition,
} from '../ui';

const BASE_URL = API_CONFIG.BASE_URL;

export default function Calories() {
  const [entries, setEntries] = useState([]);
  const [form, setForm] = useState({
    activity: '',
    duration_min: '',
    calories: '',
    protein: '',
    sugar: ''
  });
  const navigate = useNavigate();

  // Load existing entries
  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) return navigate('/');

    fetch(`${BASE_URL}/api/calories`, {
      headers: { Authorization: 'Bearer ' + token }
    })
      .then(res => {
        if (res.status === 401) {
          navigate('/'); throw new Error('Unauthorized');
        }
        if (!res.ok) throw new Error(`Fetch failed: ${res.status}`);
        return res.json();
      })
      .then(data => {
        if (Array.isArray(data)) setEntries(data);
        else setEntries([]);
      })
      .catch(() => setEntries([]));
  }, [navigate]);

  // Update form state
  const handleChange = e =>
    setForm({ ...form, [e.target.name]: e.target.value });

  // Submit new macro entry
  const handleSubmit = async e => {
    e.preventDefault();
    const token = localStorage.getItem('token');
    if (!token) return navigate('/');

    const res = await fetch(`${BASE_URL}/api/calories`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer ' + token
      },
      body: JSON.stringify({
        activity: form.activity,
        duration_min: form.duration_min,
        calories: form.calories,
        protein: form.protein,
        sugar: form.sugar
      })
    });

    if (res.ok) {
      const entry = await res.json();
      setEntries([entry, ...entries]);
      setForm({ activity: '', duration_min: '', calories: '', protein: '', sugar: '' });
    } else if (res.status === 401) {
      navigate('/');
    } else {
      console.error('Save failed:', await res.text());
    }
  };

  /* ---------- Derived values ---------- */
  const totalCalories = entries.reduce((s, e) => s + (parseFloat(e.calories) || 0), 0);
  const totalProtein = entries.reduce((s, e) => s + (parseFloat(e.protein) || 0), 0);
  const totalSugar = entries.reduce((s, e) => s + (parseFloat(e.sugar) || 0), 0);
  const totalDuration = entries.reduce((s, e) => s + (parseFloat(e.duration_min) || 0), 0);
  const dailyGoal = 2000;
  const caloriePercent = Math.min(100, Math.round((totalCalories / dailyGoal) * 100));

  const macroCards = [
    { label: 'Activity', value: `${totalDuration} min`, pct: Math.min(100, Math.round((totalDuration / 120) * 100)), color: 'bg-primary' },
    { label: 'Calories', value: `${totalCalories} kcal`, pct: caloriePercent, color: 'bg-error' },
    { label: 'Protein', value: `${totalProtein} g`, pct: Math.min(100, Math.round((totalProtein / 150) * 100)), color: 'bg-success' },
    { label: 'Sugar', value: `${totalSugar} g`, pct: Math.min(100, Math.round((totalSugar / 50) * 100)), color: 'bg-warning' },
  ];

  return (
    <PageTransition className="min-h-screen bg-deep px-4 py-6 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-5xl space-y-8">
        {/* Header */}
        <PageHeader
          title="Nutrition Tracker"
          subtitle="Log and monitor your daily macros"
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

        {/* Calorie Balance Hero */}
        <GlassCard elevated className="flex flex-col items-center py-10">
          <p className="text-label uppercase tracking-wider text-slate-400">Daily Calorie Balance</p>
          <div className="mt-4">
            <ProgressRing value={caloriePercent} size={140} strokeWidth={8} label="of goal" />
          </div>
          <p className="mt-4 text-sm text-slate-400">
            <span className="font-semibold text-slate-100">{totalCalories}</span> / {dailyGoal} kcal
          </p>
        </GlassCard>

        {/* Macro Cards */}
        <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
          {macroCards.map((card, i) => (
            <motion.div
              key={card.label}
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.06, duration: 0.3 }}
            >
              <GlassCard className="space-y-3">
                <p className="text-xs uppercase tracking-wider text-slate-400">{card.label}</p>
                <p className="text-lg font-bold text-slate-50">{card.value}</p>
                <div className="h-1.5 w-full overflow-hidden rounded-full bg-white/5">
                  <div
                    className={`h-full rounded-full transition-all duration-700 ${card.color}`}
                    style={{ width: `${card.pct}%` }}
                  />
                </div>
              </GlassCard>
            </motion.div>
          ))}
        </div>

        {/* Log Entry Form */}
        <GlassCard>
          <h2 className="mb-5 text-lg font-semibold text-slate-100">Log Entry</h2>
          <form onSubmit={handleSubmit} className="space-y-5">
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
              <div className="space-y-1.5">
                <label className="text-label text-slate-300">Activity</label>
                <input
                  name="activity"
                  placeholder="e.g. Running"
                  value={form.activity}
                  onChange={handleChange}
                  className="h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 placeholder-slate-500 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/40"
                  required
                />
              </div>
              <div className="space-y-1.5">
                <label className="text-label text-slate-300">Duration (min)</label>
                <input
                  name="duration_min"
                  type="number"
                  placeholder="30"
                  value={form.duration_min}
                  onChange={handleChange}
                  className="h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 placeholder-slate-500 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/40"
                  required
                />
              </div>
              <div className="space-y-1.5">
                <label className="text-label text-slate-300">Calories</label>
                <input
                  name="calories"
                  type="number"
                  placeholder="250"
                  value={form.calories}
                  onChange={handleChange}
                  className="h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 placeholder-slate-500 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/40"
                  required
                />
              </div>
              <div className="space-y-1.5">
                <label className="text-label text-slate-300">Protein (g)</label>
                <input
                  name="protein"
                  type="number"
                  placeholder="20"
                  value={form.protein}
                  onChange={handleChange}
                  className="h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 placeholder-slate-500 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/40"
                  required
                />
              </div>
              <div className="space-y-1.5">
                <label className="text-label text-slate-300">Sugar (g)</label>
                <input
                  name="sugar"
                  type="number"
                  placeholder="5"
                  value={form.sugar}
                  onChange={handleChange}
                  className="h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 placeholder-slate-500 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/40"
                  required
                />
              </div>
            </div>
            <div className="flex justify-end pt-2">
              <ActionButton type="submit">
                Log Entry
              </ActionButton>
            </div>
          </form>
        </GlassCard>

        {/* Daily History */}
        <div className="space-y-4">
          <h2 className="text-lg font-semibold text-slate-100">Daily History</h2>

          {!Array.isArray(entries) ? (
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
              <LoadingSkeleton variant="card" count={4} />
            </div>
          ) : entries.length === 0 ? (
            <GlassCard>
              <EmptyState
                icon={<span className="text-2xl">🍽️</span>}
                title="No entries yet"
                message="Log your first activity or meal to start tracking your nutrition."
              />
            </GlassCard>
          ) : (
            <div className="space-y-3">
              {entries.map((entry, i) => (
                <motion.div
                  key={entry.id}
                  initial={{ opacity: 0, y: 12 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: i * 0.04, duration: 0.3 }}
                >
                  <GlassCard className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                    {/* Left */}
                    <div className="flex items-center gap-4">
                      <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-lg">
                        🏃
                      </div>
                      <div>
                        <p className="font-semibold text-slate-100">{entry.activity}</p>
                        <p className="mt-0.5 text-xs text-slate-500">{entry.duration_min} min &middot; {entry.entry_date}</p>
                      </div>
                    </div>

                    {/* Right: macro badges */}
                    <div className="flex flex-wrap items-center gap-2">
                      <Badge variant="severity">{entry.calories} kcal</Badge>
                      <Badge variant="status">{entry.protein}g protein</Badge>
                      <Badge variant="meal">{entry.sugar}g sugar</Badge>
                    </div>
                  </GlassCard>
                </motion.div>
              ))}
            </div>
          )}
        </div>
      </div>
    </PageTransition>
  );
}
