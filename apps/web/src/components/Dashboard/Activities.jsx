// frontend/src/components/Dashboard/Activities.jsx
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

export default function Activities() {
  const [entries, setEntries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({
    activity: '',
    duration_min: '',
    calories: '',
    intensity: 'Moderate',
    type: 'Cardio'
  });
  const navigate = useNavigate();

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) return navigate('/');

    fetchActivitiesData();
  }, [navigate]);

  const fetchActivitiesData = async () => {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${BASE_URL}/api/activities`, {
        headers: { Authorization: 'Bearer ' + token }
      });

      if (res.status === 401) {
        navigate('/');
        return;
      }

      if (!res.ok) throw new Error(`Fetch failed: ${res.status}`);

      const data = await res.json();
      setEntries(Array.isArray(data) ? data : []);
    } catch (error) {
      console.error('Error fetching activities data:', error);
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

      const res = await fetch(`${BASE_URL}/api/activities`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer ' + token
        },
        body: JSON.stringify({
          activity: form.activity,
          duration_min: form.duration_min,
          calories: form.calories,
          intensity: form.intensity,
          type: form.type
        })
      });

      if (res.ok) {
        const entry = await res.json();
        setEntries([entry, ...entries]);
        setForm({
          activity: '',
          duration_min: '',
          calories: '',
          intensity: 'Moderate',
          type: 'Cardio'
        });
        alert('Activity logged successfully!');
      } else if (res.status === 401) {
        navigate('/');
      } else {
        const errorText = await res.text();
        console.error('Save failed:', errorText);
        alert('Error: ' + errorText);
      }
    } catch (error) {
      console.error('Error saving activity data:', error);
      alert('Error saving activity data');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure you want to delete this activity?')) return;

    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${BASE_URL}/api/activities/${id}`, {
        method: 'DELETE',
        headers: { Authorization: 'Bearer ' + token }
      });

      if (res.ok) {
        setEntries(entries.filter(entry => entry.id !== id));
        alert('Activity deleted successfully!');
      } else {
        alert('Error deleting activity');
      }
    } catch (error) {
      console.error('Error deleting activity:', error);
      alert('Error deleting activity');
    }
  };

  const calculateActivityStats = () => {
    if (entries.length === 0) return null;

    const totalCalories = entries.reduce((sum, entry) => sum + parseFloat(entry.calories || 0), 0);
    const totalDuration = entries.reduce((sum, entry) => sum + parseFloat(entry.duration_min || 0), 0);
    const avgCalories = totalCalories / entries.length;
    const avgDuration = totalDuration / entries.length;

    return {
      totalCalories: totalCalories.toFixed(0),
      totalDuration: totalDuration.toFixed(0),
      avgCalories: avgCalories.toFixed(0),
      avgDuration: avgDuration.toFixed(0),
      totalEntries: entries.length
    };
  };

  const stats = calculateActivityStats();

  const getActivityIcon = (activity) => {
    const activityLower = activity?.toLowerCase();
    if (activityLower.includes('run')) return '🏃‍♂️';
    if (activityLower.includes('walk')) return '🚶‍♂️';
    if (activityLower.includes('bike') || activityLower.includes('cycle')) return '🚴‍♂️';
    if (activityLower.includes('swim')) return '🏊‍♂️';
    if (activityLower.includes('gym') || activityLower.includes('weight')) return '🏋️‍♂️';
    if (activityLower.includes('yoga')) return '🧘‍♀️';
    if (activityLower.includes('dance')) return '💃';
    if (activityLower.includes('hike')) return '🥾';
    return '🏃‍♂️';
  };

  const getIntensityColor = (intensity) => {
    switch (intensity?.toLowerCase()) {
      case 'low': return '#10b981';
      case 'moderate': return '#f59e0b';
      case 'high': return '#ef4444';
      default: return '#6b7280';
    }
  };

  const getIntensityClasses = (intensity) => {
    switch (intensity?.toLowerCase()) {
      case 'low': return 'bg-emerald-500';
      case 'moderate': return 'bg-amber-500';
      case 'high': return 'bg-red-500';
      default: return 'bg-slate-500';
    }
  };

  const formatDuration = (minutes) => {
    if (minutes < 60) return `${minutes} min`;
    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;
    return mins > 0 ? `${hours}h ${mins}m` : `${hours}h`;
  };

  const [showForm, setShowForm] = useState(false);
  const [activeFilter, setActiveFilter] = useState('all');
  const filters = ['All', 'Today', 'This Week', 'This Month'];

  return (
    <PageTransition className="min-h-screen bg-deep px-4 pb-24 pt-6 sm:px-6 lg:px-8">
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
          title="Activity Tracker"
          subtitle="Track your workouts and stay active"
          action={
            <ActionButton
              variant="primary"
              className="h-11"
              onClick={() => {
                setShowForm(!showForm);
                if (!showForm) {
                  setTimeout(() => {
                    document.getElementById('activity-form-section')?.scrollIntoView({ behavior: 'smooth' });
                  }, 100);
                }
              }}
              icon={
                <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
                </svg>
              }
            >
              Log Activity
            </ActionButton>
          }
        />
      </div>

      {/* ---- FILTER PILLS ---- */}
      <div className="mb-6 flex flex-wrap gap-2">
        {filters.map((filter) => (
          <button
            key={filter}
            onClick={() => setActiveFilter(filter.toLowerCase().replace(/ /g, '_'))}
            className={`h-9 rounded-full px-4 text-sm font-medium transition-all duration-200 ${
              activeFilter === filter.toLowerCase().replace(/ /g, '_')
                ? 'bg-gradient-primary text-white shadow-glow-sm'
                : 'border border-border-subtle bg-surface-1 text-slate-400 hover:bg-surface-2 hover:text-slate-200'
            }`}
          >
            {filter}
          </button>
        ))}
      </div>

      {/* ---- STATS ---- */}
      {stats && (
        <div className="mb-6 grid grid-cols-2 gap-3 lg:grid-cols-4">
          <StatCard
            icon={
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M15.362 5.214A8.252 8.252 0 0112 21 8.25 8.25 0 016.038 7.048 8.287 8.287 0 009 9.6a8.983 8.983 0 013.361-6.867 8.21 8.21 0 003 2.48z" />
              </svg>
            }
            label="Total Calories Burned"
            value={stats.totalCalories}
          />
          <StatCard
            icon={
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            }
            label="Total Duration"
            value={formatDuration(stats.totalDuration)}
          />
          <StatCard
            icon={
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75z" />
              </svg>
            }
            label="Avg Calories / Activity"
            value={stats.avgCalories}
          />
          <StatCard
            icon={
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3 3v1.5M3 21v-6m0 0l2.77-.693a9 9 0 016.208.682l.108.054a9 9 0 006.086.71l3.114-.732a48.524 48.524 0 01-.005-10.499l-3.11.732a9 9 0 01-6.085-.711l-.108-.054a9 9 0 00-6.208-.682L3 4.5M3 15V4.5" />
              </svg>
            }
            label="Total Activities"
            value={stats.totalEntries}
          />
        </div>
      )}

      {/* ---- ACTIVITY FORM ---- */}
      <AnimatePresence>
        {showForm && (
          <motion.div
            id="activity-form-section"
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
            className="mb-6 overflow-hidden"
          >
            <GlassCard elevated hover={false}>
              <h2 className="mb-5 text-lg font-semibold text-slate-100">Log Activity</h2>
              <form onSubmit={handleSubmit} className="space-y-4">
                <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
                  {/* Activity Name */}
                  <div>
                    <label className="mb-1.5 block text-sm font-medium text-slate-300">
                      Activity Name
                    </label>
                    <input
                      name="activity"
                      type="text"
                      placeholder="e.g., Running, Weight Training"
                      value={form.activity}
                      onChange={handleChange}
                      required
                      className="h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 placeholder-slate-500 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/50"
                    />
                  </div>
                  {/* Duration */}
                  <div>
                    <label className="mb-1.5 block text-sm font-medium text-slate-300">
                      Duration (minutes)
                    </label>
                    <input
                      name="duration_min"
                      type="number"
                      min="1"
                      placeholder="30"
                      value={form.duration_min}
                      onChange={handleChange}
                      required
                      className="h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 placeholder-slate-500 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/50"
                    />
                  </div>
                  {/* Calories */}
                  <div>
                    <label className="mb-1.5 block text-sm font-medium text-slate-300">
                      Calories Burned
                    </label>
                    <input
                      name="calories"
                      type="number"
                      min="0"
                      placeholder="300"
                      value={form.calories}
                      onChange={handleChange}
                      required
                      className="h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 placeholder-slate-500 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/50"
                    />
                  </div>
                  {/* Intensity */}
                  <div>
                    <label className="mb-1.5 block text-sm font-medium text-slate-300">
                      Intensity Level
                    </label>
                    <select
                      name="intensity"
                      value={form.intensity}
                      onChange={handleChange}
                      required
                      className="h-11 w-full appearance-none rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/50"
                    >
                      <option value="Low">Low</option>
                      <option value="Moderate">Moderate</option>
                      <option value="High">High</option>
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
                    {saving ? 'Logging...' : 'Log Activity'}
                  </ActionButton>
                </div>
              </form>
            </GlassCard>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ---- ACTIVITY CARDS ---- */}
      <section>
        <h2 className="mb-4 text-lg font-semibold text-slate-200">Activity History</h2>

        {loading ? (
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <LoadingSkeleton variant="card" count={4} />
          </div>
        ) : entries.length === 0 ? (
          <GlassCard hover={false}>
            <EmptyState
              icon={
                <svg className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
                </svg>
              }
              title="No Activities Yet"
              message="Start tracking your workouts to see your progress and stay motivated."
              action={{ label: 'Log Activity', onClick: () => setShowForm(true) }}
            />
          </GlassCard>
        ) : (
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            {entries.map((entry, index) => (
              <motion.div
                key={entry.id}
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: index * 0.03 }}
              >
                <GlassCard className="group relative" as="article">
                  {/* Top row: icon + name + intensity + delete */}
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex items-center gap-3">
                      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-lg">
                        {getActivityIcon(entry.activity)}
                      </div>
                      <div>
                        <p className="font-semibold text-slate-100">{entry.activity}</p>
                        <p className="text-xs text-slate-400">{entry.entry_date}</p>
                      </div>
                    </div>

                    <div className="flex items-center gap-2">
                      {entry.intensity && (
                        <div className="flex items-center gap-1.5">
                          <span className={`inline-block h-2 w-2 rounded-full ${getIntensityClasses(entry.intensity)}`} />
                          <span className="text-xs font-medium text-slate-400">{entry.intensity}</span>
                        </div>
                      )}
                      <button
                        onClick={() => handleDelete(entry.id)}
                        className="flex h-8 w-8 items-center justify-center rounded-lg text-slate-500 opacity-0 transition-all hover:bg-error/10 hover:text-error group-hover:opacity-100"
                        title="Delete"
                      >
                        <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <path strokeLinecap="round" strokeLinejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                        </svg>
                      </button>
                    </div>
                  </div>

                  {/* Bottom row: badges */}
                  <div className="mt-4 flex flex-wrap items-center gap-2">
                    <Badge variant="intensity">
                      <svg className="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M15.362 5.214A8.252 8.252 0 0112 21 8.25 8.25 0 016.038 7.048 8.287 8.287 0 009 9.6a8.983 8.983 0 013.361-6.867 8.21 8.21 0 003 2.48z" />
                      </svg>
                      {entry.calories} cal
                    </Badge>
                    <Badge variant="status">
                      <svg className="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      {formatDuration(entry.duration_min)}
                    </Badge>
                  </div>
                </GlassCard>
              </motion.div>
            ))}
          </div>
        )}
      </section>
    </PageTransition>
  );
}
