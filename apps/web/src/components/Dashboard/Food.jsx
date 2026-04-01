// frontend/src/components/Dashboard/Food.jsx
import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import API_CONFIG from '../../config';
import {
  GlassCard,
  StatCard,
  PageHeader,
  ActionButton,
  Badge,
  EmptyState,
  LoadingSkeleton,
  PageTransition,
} from '../ui';

const BASE_URL = API_CONFIG.BASE_URL;

const mealOrder = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

export default function Food() {
  const [entries, setEntries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({
    name: '',
    calories: '',
    protein: '',
    sugar: '',
    carbs: '',
    fat: '',
    mealType: 'Snack'
  });
  const navigate = useNavigate();

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) return navigate('/');

    fetchFoodData();
  }, [navigate]);

  const fetchFoodData = async () => {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${BASE_URL}/api/food`, {
        headers: { Authorization: 'Bearer ' + token }
      });

      if (res.status === 401) {
        navigate('/');
        return;
      }

      const data = await res.json();
      setEntries(Array.isArray(data) ? data : []);
    } catch (error) {
      console.error('Error fetching food data:', error);
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

      const res = await fetch(`${BASE_URL}/api/food`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer ' + token
        },
        body: JSON.stringify(form)
      });

      if (res.ok) {
        const entry = await res.json();
        setEntries([entry, ...entries]);
        setForm({
          name: '',
          calories: '',
          protein: '',
          sugar: '',
          carbs: '',
          fat: '',
          mealType: 'Snack'
        });
        alert('Food logged successfully!');
      } else if (res.status === 401) {
        navigate('/');
      } else {
        const errorText = await res.text();
        console.error('Save failed:', errorText);
        alert('Error: ' + errorText);
      }
    } catch (error) {
      console.error('Error saving food data:', error);
      alert('Error saving food data');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure you want to delete this food entry?')) return;

    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${BASE_URL}/api/food/${id}`, {
        method: 'DELETE',
        headers: { Authorization: 'Bearer ' + token }
      });

      if (res.ok) {
        setEntries(entries.filter(entry => entry.id !== id));
        alert('Food entry deleted successfully!');
      } else {
        alert('Error deleting food entry');
      }
    } catch (error) {
      console.error('Error deleting food:', error);
      alert('Error deleting food entry');
    }
  };

  const calculateNutritionStats = () => {
    if (entries.length === 0) return null;

    const totalCalories = entries.reduce((sum, entry) => sum + parseFloat(entry.calories || 0), 0);
    const totalProtein = entries.reduce((sum, entry) => sum + parseFloat(entry.protein || 0), 0);
    const totalSugar = entries.reduce((sum, entry) => sum + parseFloat(entry.sugar || 0), 0);
    const totalCarbs = entries.reduce((sum, entry) => sum + parseFloat(entry.carbs || 0), 0);
    const totalFat = entries.reduce((sum, entry) => sum + parseFloat(entry.fat || 0), 0);

    return {
      totalCalories: totalCalories.toFixed(0),
      totalProtein: totalProtein.toFixed(1),
      totalSugar: totalSugar.toFixed(1),
      totalCarbs: totalCarbs.toFixed(1),
      totalFat: totalFat.toFixed(1),
      avgCalories: (totalCalories / entries.length).toFixed(0),
      totalEntries: entries.length
    };
  };

  const stats = calculateNutritionStats();

  const getMealTypeIcon = (mealType) => {
    switch (mealType?.toLowerCase()) {
      case 'breakfast': return '🌅';
      case 'lunch': return '🌞';
      case 'dinner': return '🌙';
      case 'snack': return '🍎';
      default: return '🍽️';
    }
  };

  const getMealTypeColor = (mealType) => {
    switch (mealType?.toLowerCase()) {
      case 'breakfast': return '#f59e0b';
      case 'lunch': return '#10b981';
      case 'dinner': return '#8b5cf6';
      case 'snack': return '#ec4899';
      default: return '#6b7280';
    }
  };

  const getMealTypeBadgeVariant = (mealType) => {
    switch (mealType?.toLowerCase()) {
      case 'breakfast': return 'meal';
      case 'lunch': return 'status';
      case 'dinner': return 'intensity';
      case 'snack': return 'severity';
      default: return 'status';
    }
  };

  // Local state for form visibility and meal section collapse
  const [showForm, setShowForm] = useState(false);
  const [collapsedSections, setCollapsedSections] = useState({});

  const toggleSection = (meal) => {
    setCollapsedSections(prev => ({ ...prev, [meal]: !prev[meal] }));
  };

  // Group entries by meal type
  const groupedEntries = entries.reduce((groups, entry) => {
    const meal = entry.meal_type || entry.mealType || 'Snack';
    if (!groups[meal]) groups[meal] = [];
    groups[meal].push(entry);
    return groups;
  }, {});

  // Macro progress helper
  const macroBar = (label, value, total, gradient) => {
    const pct = total > 0 ? Math.min(100, (value / total) * 100) : 0;
    return (
      <div>
        <div className="mb-1.5 flex items-center justify-between text-sm">
          <span className="text-slate-400">{label}</span>
          <span className="font-semibold text-slate-200">{value}g</span>
        </div>
        <div className="h-2 w-full overflow-hidden rounded-full bg-surface-3">
          <div
            className={`h-full rounded-full transition-all duration-700 ease-out ${gradient}`}
            style={{ width: `${pct}%` }}
          />
        </div>
      </div>
    );
  };

  return (
    <PageTransition className="min-h-screen bg-deep px-4 pb-32 pt-6 sm:px-6 lg:px-8">
      {/* ---- HEADER ---- */}
      <div className="mb-6">
        <button
          onClick={() => navigate('/dashboard')}
          className="mb-4 inline-flex h-11 items-center gap-1.5 rounded-xl px-3 text-sm font-medium text-slate-400 transition-colors hover:bg-white/5 hover:text-slate-200"
        >
          <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18" />
          </svg>
          Dashboard
        </button>

        <PageHeader
          title="Food Tracker"
          subtitle="Track your nutrition and maintain a healthy diet"
        />
      </div>

      {/* ---- DAILY MACRO SUMMARY BAR ---- */}
      {stats && (
        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="mb-6"
        >
          <GlassCard elevated hover={false}>
            <div className="mb-4 flex items-center justify-between">
              <h2 className="text-base font-semibold text-slate-100">Macro Distribution</h2>
              <span className="text-sm font-semibold text-primary-bright">{stats.totalCalories} cal total</span>
            </div>

            <div className="space-y-4">
              {/* Calories overall bar */}
              <div>
                <div className="mb-1.5 flex items-center justify-between text-sm">
                  <span className="text-slate-400">Calories</span>
                  <span className="font-semibold text-slate-200">{stats.totalCalories}</span>
                </div>
                <div className="h-2.5 w-full overflow-hidden rounded-full bg-surface-3">
                  <div
                    className="h-full rounded-full bg-gradient-to-r from-violet-500 to-fuchsia-500 transition-all duration-700 ease-out"
                    style={{ width: '100%' }}
                  />
                </div>
              </div>

              {macroBar(
                `Protein (${parseFloat(stats.totalCalories) > 0 ? ((parseFloat(stats.totalProtein) * 4 / parseFloat(stats.totalCalories)) * 100).toFixed(0) : 0}%)`,
                stats.totalProtein,
                parseFloat(stats.totalCalories) / 4,
                'bg-gradient-to-r from-blue-500 to-blue-400'
              )}
              {macroBar(
                `Carbs (${parseFloat(stats.totalCalories) > 0 ? ((parseFloat(stats.totalCarbs) * 4 / parseFloat(stats.totalCalories)) * 100).toFixed(0) : 0}%)`,
                stats.totalCarbs,
                parseFloat(stats.totalCalories) / 4,
                'bg-gradient-to-r from-amber-500 to-amber-400'
              )}
              {macroBar(
                `Fat (${parseFloat(stats.totalCalories) > 0 ? ((parseFloat(stats.totalFat) * 9 / parseFloat(stats.totalCalories)) * 100).toFixed(0) : 0}%)`,
                stats.totalFat,
                parseFloat(stats.totalCalories) / 9,
                'bg-gradient-to-r from-emerald-500 to-emerald-400'
              )}
              {macroBar(
                'Sugar',
                stats.totalSugar,
                50,
                'bg-gradient-to-r from-pink-500 to-rose-400'
              )}
            </div>
          </GlassCard>
        </motion.div>
      )}

      {/* ---- STAT CARDS ---- */}
      {stats && (
        <div className="mb-6 grid grid-cols-2 gap-3 lg:grid-cols-4">
          <StatCard
            icon={
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M15.362 5.214A8.252 8.252 0 0112 21 8.25 8.25 0 016.038 7.048 8.287 8.287 0 009 9.6a8.983 8.983 0 013.361-6.867 8.21 8.21 0 003 2.48z" />
              </svg>
            }
            label="Total Calories"
            value={stats.totalCalories}
          />
          <StatCard
            icon={
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
              </svg>
            }
            label="Total Protein"
            value={`${stats.totalProtein}g`}
          />
          <StatCard
            icon={
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 8.25v-1.5m0 1.5c-1.355 0-2.697.056-4.024.166C6.845 8.51 6 9.473 6 10.608v2.513m6-4.871c1.355 0 2.697.056 4.024.166C17.155 8.51 18 9.473 18 10.608v2.513" />
              </svg>
            }
            label="Total Carbs"
            value={`${stats.totalCarbs}g`}
          />
          <StatCard
            icon={
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z" />
              </svg>
            }
            label="Total Fat"
            value={`${stats.totalFat}g`}
          />
        </div>
      )}

      {/* ---- FOOD FORM (toggled by FAB) ---- */}
      <AnimatePresence>
        {showForm && (
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 16 }}
            transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
            className="mb-6"
          >
            <GlassCard elevated hover={false}>
              <div className="mb-5 flex items-center justify-between">
                <h2 className="text-lg font-semibold text-slate-100">Log Food</h2>
                <button
                  onClick={() => setShowForm(false)}
                  className="flex h-8 w-8 items-center justify-center rounded-lg text-slate-400 transition-colors hover:bg-white/10 hover:text-slate-200"
                >
                  <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>

              <form onSubmit={handleSubmit} className="space-y-4">
                <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
                  {/* Food Name */}
                  <div>
                    <label className="mb-1.5 block text-sm font-medium text-slate-300">Food Name</label>
                    <input
                      name="name"
                      type="text"
                      placeholder="e.g., Grilled Chicken Breast"
                      value={form.name}
                      onChange={handleChange}
                      required
                      className="h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 placeholder-slate-500 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/50"
                    />
                  </div>
                  {/* Calories */}
                  <div>
                    <label className="mb-1.5 block text-sm font-medium text-slate-300">Calories</label>
                    <input
                      name="calories"
                      type="number"
                      min="0"
                      placeholder="250"
                      value={form.calories}
                      onChange={handleChange}
                      required
                      className="h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 placeholder-slate-500 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/50"
                    />
                  </div>
                  {/* Protein */}
                  <div>
                    <label className="mb-1.5 block text-sm font-medium text-slate-300">Protein (g)</label>
                    <input
                      name="protein"
                      type="number"
                      step="0.1"
                      min="0"
                      placeholder="25"
                      value={form.protein}
                      onChange={handleChange}
                      required
                      className="h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 placeholder-slate-500 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/50"
                    />
                  </div>
                  {/* Carbs */}
                  <div>
                    <label className="mb-1.5 block text-sm font-medium text-slate-300">Carbs (g)</label>
                    <input
                      name="carbs"
                      type="number"
                      step="0.1"
                      min="0"
                      placeholder="15"
                      value={form.carbs}
                      onChange={handleChange}
                      required
                      className="h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 placeholder-slate-500 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/50"
                    />
                  </div>
                  {/* Fat */}
                  <div>
                    <label className="mb-1.5 block text-sm font-medium text-slate-300">Fat (g)</label>
                    <input
                      name="fat"
                      type="number"
                      step="0.1"
                      min="0"
                      placeholder="8"
                      value={form.fat}
                      onChange={handleChange}
                      required
                      className="h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 placeholder-slate-500 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/50"
                    />
                  </div>
                  {/* Sugar */}
                  <div>
                    <label className="mb-1.5 block text-sm font-medium text-slate-300">Sugar (g)</label>
                    <input
                      name="sugar"
                      type="number"
                      step="0.1"
                      min="0"
                      placeholder="5"
                      value={form.sugar}
                      onChange={handleChange}
                      required
                      className="h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 placeholder-slate-500 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/50"
                    />
                  </div>
                  {/* Meal Type */}
                  <div>
                    <label className="mb-1.5 block text-sm font-medium text-slate-300">Meal Type</label>
                    <select
                      name="mealType"
                      value={form.mealType}
                      onChange={handleChange}
                      required
                      className="h-11 w-full appearance-none rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/50"
                    >
                      <option value="Breakfast">Breakfast</option>
                      <option value="Lunch">Lunch</option>
                      <option value="Dinner">Dinner</option>
                      <option value="Snack">Snack</option>
                    </select>
                  </div>
                </div>

                <div className="flex justify-end pt-2">
                  <ActionButton
                    type="submit"
                    variant="primary"
                    loading={saving}
                    disabled={saving}
                    className="h-11"
                  >
                    {saving ? 'Logging...' : 'Log Food'}
                  </ActionButton>
                </div>
              </form>
            </GlassCard>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ---- MEAL SECTIONS ---- */}
      <section>
        <h2 className="mb-4 text-lg font-semibold text-slate-200">Food History</h2>

        {loading ? (
          <div className="space-y-4">
            <LoadingSkeleton variant="card" count={3} />
          </div>
        ) : entries.length === 0 ? (
          <GlassCard hover={false}>
            <EmptyState
              icon={
                <svg className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M12 8.25v-1.5m0 1.5c-1.355 0-2.697.056-4.024.166C6.845 8.51 6 9.473 6 10.608v2.513m6-4.871c1.355 0 2.697.056 4.024.166C17.155 8.51 18 9.473 18 10.608v2.513M15 8.25v-1.5m-6 1.5v-1.5m12 9.75l-1.5.75a3.354 3.354 0 01-3 0 3.354 3.354 0 00-3 0 3.354 3.354 0 01-3 0 3.354 3.354 0 00-3 0 3.354 3.354 0 01-3 0L3 16.5" />
                </svg>
              }
              title="No Food Data Yet"
              message="Start tracking your meals to monitor your nutrition and maintain a healthy diet."
              action={{ label: 'Log Food', onClick: () => setShowForm(true) }}
            />
          </GlassCard>
        ) : (
          <div className="space-y-4">
            {mealOrder.map((meal) => {
              const items = groupedEntries[meal];
              if (!items || items.length === 0) return null;
              const isCollapsed = collapsedSections[meal];

              return (
                <GlassCard key={meal} hover={false} className="overflow-hidden !p-0">
                  {/* Section header (collapsible) */}
                  <button
                    onClick={() => toggleSection(meal)}
                    className="flex w-full items-center justify-between px-5 py-4 text-left transition-colors hover:bg-white/[0.02]"
                  >
                    <div className="flex items-center gap-3">
                      <span className="text-xl">{getMealTypeIcon(meal)}</span>
                      <span className="text-base font-semibold text-slate-100">{meal}</span>
                      <Badge variant={getMealTypeBadgeVariant(meal)}>
                        {items.length} {items.length === 1 ? 'item' : 'items'}
                      </Badge>
                    </div>
                    <svg
                      className={`h-5 w-5 text-slate-400 transition-transform duration-200 ${isCollapsed ? '' : 'rotate-180'}`}
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      strokeWidth={2}
                    >
                      <path strokeLinecap="round" strokeLinejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5" />
                    </svg>
                  </button>

                  {/* Items */}
                  <AnimatePresence initial={false}>
                    {!isCollapsed && (
                      <motion.div
                        initial={{ height: 0, opacity: 0 }}
                        animate={{ height: 'auto', opacity: 1 }}
                        exit={{ height: 0, opacity: 0 }}
                        transition={{ duration: 0.25, ease: [0.16, 1, 0.3, 1] }}
                        className="overflow-hidden"
                      >
                        <div className="border-t border-white/5 px-5 py-3">
                          <div className="space-y-3">
                            {items.map((entry) => (
                              <div
                                key={entry.id}
                                className="group flex items-start justify-between gap-3 rounded-xl bg-surface-1 p-3 transition-colors hover:bg-surface-2"
                              >
                                <div className="min-w-0 flex-1">
                                  <p className="font-medium text-slate-100">{entry.name}</p>
                                  <div className="mt-2 flex flex-wrap gap-1.5">
                                    <Badge variant="intensity">{entry.calories} cal</Badge>
                                    <Badge variant="status">P: {entry.protein || 0}g</Badge>
                                    <Badge variant="meal">C: {entry.carbs || 0}g</Badge>
                                    <Badge variant="status">F: {entry.fat || 0}g</Badge>
                                    {parseFloat(entry.sugar) > 0 && (
                                      <Badge variant="severity">S: {entry.sugar}g</Badge>
                                    )}
                                  </div>
                                  {entry.entry_date && (
                                    <p className="mt-1.5 text-xs text-slate-500">{entry.entry_date}</p>
                                  )}
                                </div>

                                <button
                                  onClick={() => handleDelete(entry.id)}
                                  className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-slate-500 opacity-0 transition-all hover:bg-error/10 hover:text-error group-hover:opacity-100"
                                  title="Delete"
                                >
                                  <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                                    <path strokeLinecap="round" strokeLinejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                                  </svg>
                                </button>
                              </div>
                            ))}
                          </div>
                        </div>
                      </motion.div>
                    )}
                  </AnimatePresence>
                </GlassCard>
              );
            })}

            {/* Show any entries with non-standard meal types */}
            {Object.keys(groupedEntries)
              .filter(m => !mealOrder.includes(m))
              .map((meal) => {
                const items = groupedEntries[meal];
                if (!items || items.length === 0) return null;
                const isCollapsed = collapsedSections[meal];

                return (
                  <GlassCard key={meal} hover={false} className="overflow-hidden !p-0">
                    <button
                      onClick={() => toggleSection(meal)}
                      className="flex w-full items-center justify-between px-5 py-4 text-left transition-colors hover:bg-white/[0.02]"
                    >
                      <div className="flex items-center gap-3">
                        <span className="text-xl">{getMealTypeIcon(meal)}</span>
                        <span className="text-base font-semibold text-slate-100">{meal}</span>
                        <Badge variant="status">
                          {items.length} {items.length === 1 ? 'item' : 'items'}
                        </Badge>
                      </div>
                      <svg
                        className={`h-5 w-5 text-slate-400 transition-transform duration-200 ${isCollapsed ? '' : 'rotate-180'}`}
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                        strokeWidth={2}
                      >
                        <path strokeLinecap="round" strokeLinejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5" />
                      </svg>
                    </button>

                    <AnimatePresence initial={false}>
                      {!isCollapsed && (
                        <motion.div
                          initial={{ height: 0, opacity: 0 }}
                          animate={{ height: 'auto', opacity: 1 }}
                          exit={{ height: 0, opacity: 0 }}
                          transition={{ duration: 0.25, ease: [0.16, 1, 0.3, 1] }}
                          className="overflow-hidden"
                        >
                          <div className="border-t border-white/5 px-5 py-3">
                            <div className="space-y-3">
                              {items.map((entry) => (
                                <div
                                  key={entry.id}
                                  className="group flex items-start justify-between gap-3 rounded-xl bg-surface-1 p-3 transition-colors hover:bg-surface-2"
                                >
                                  <div className="min-w-0 flex-1">
                                    <p className="font-medium text-slate-100">{entry.name}</p>
                                    <div className="mt-2 flex flex-wrap gap-1.5">
                                      <Badge variant="intensity">{entry.calories} cal</Badge>
                                      <Badge variant="status">P: {entry.protein || 0}g</Badge>
                                      <Badge variant="meal">C: {entry.carbs || 0}g</Badge>
                                      <Badge variant="status">F: {entry.fat || 0}g</Badge>
                                      {parseFloat(entry.sugar) > 0 && (
                                        <Badge variant="severity">S: {entry.sugar}g</Badge>
                                      )}
                                    </div>
                                    {entry.entry_date && (
                                      <p className="mt-1.5 text-xs text-slate-500">{entry.entry_date}</p>
                                    )}
                                  </div>
                                  <button
                                    onClick={() => handleDelete(entry.id)}
                                    className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-slate-500 opacity-0 transition-all hover:bg-error/10 hover:text-error group-hover:opacity-100"
                                    title="Delete"
                                  >
                                    <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                                      <path strokeLinecap="round" strokeLinejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                                    </svg>
                                  </button>
                                </div>
                              ))}
                            </div>
                          </div>
                        </motion.div>
                      )}
                    </AnimatePresence>
                  </GlassCard>
                );
              })}
          </div>
        )}
      </section>

      {/* ---- FLOATING ACTION BUTTON ---- */}
      <button
        onClick={() => setShowForm(!showForm)}
        className="fixed bottom-6 right-6 z-50 flex h-14 w-14 items-center justify-center rounded-full bg-gradient-primary text-white shadow-glow-lg transition-all duration-200 hover:scale-105 hover:shadow-glow-primary active:scale-95"
        title="Log Food"
      >
        <svg
          className={`h-6 w-6 transition-transform duration-200 ${showForm ? 'rotate-45' : ''}`}
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          strokeWidth={2}
        >
          <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
        </svg>
      </button>
    </PageTransition>
  );
}
