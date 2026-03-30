import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
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

export default function Sleep() {
  const [entries, setEntries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({
    hours: '',
    quality: 'Good',
    bedtime: '',
    wakeTime: ''
  });
  const navigate = useNavigate();

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) return navigate('/');

    fetchSleepData();
  }, [navigate]);

  const fetchSleepData = async () => {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${BASE_URL}/api/sleep`, {
        headers: { Authorization: 'Bearer ' + token }
      });

      if (res.status === 401) {
        navigate('/');
        return;
      }

      const data = await res.json();
      setEntries(Array.isArray(data) ? data : []);
    } catch (error) {
      console.error('Error fetching sleep data:', error);
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

      const res = await fetch(`${BASE_URL}/api/sleep`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer ' + token
        },
        body: JSON.stringify({
          hours: form.hours,
          quality: form.quality,
          bedtime: form.bedtime,
          wakeTime: form.wakeTime
        })
      });

      if (res.ok) {
        const entry = await res.json();
        setEntries([entry, ...entries]);
        setForm({ hours: '', quality: 'Good', bedtime: '', wakeTime: '' });
        alert('Sleep logged successfully!');
      } else if (res.status === 401) {
        navigate('/');
      } else {
        const errorText = await res.text();
        console.error('Save failed:', errorText);
        alert('Error: ' + errorText);
      }
    } catch (error) {
      console.error('Error saving sleep data:', error);
      alert('Error saving sleep data');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure you want to delete this sleep entry?')) return;

    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${BASE_URL}/api/sleep/${id}`, {
        method: 'DELETE',
        headers: { Authorization: 'Bearer ' + token }
      });

      if (res.ok) {
        setEntries(entries.filter(entry => entry.id !== id));
        alert('Sleep entry deleted successfully!');
      } else {
        alert('Error deleting sleep entry');
      }
    } catch (error) {
      console.error('Error deleting sleep:', error);
      alert('Error deleting sleep entry');
    }
  };

  const getSleepQualityColor = (quality) => {
    switch (quality?.toLowerCase()) {
      case 'excellent': return '#10b981';
      case 'good': return '#3b82f6';
      case 'fair': return '#f59e0b';
      case 'poor': return '#ef4444';
      default: return '#6b7280';
    }
  };

  const getSleepQualityIcon = (quality) => {
    switch (quality?.toLowerCase()) {
      case 'excellent': return '😴';
      case 'good': return '😊';
      case 'fair': return '😐';
      case 'poor': return '😫';
      default: return '😴';
    }
  };

  const calculateSleepStats = () => {
    if (entries.length === 0) return null;

    const totalHours = entries.reduce((sum, entry) => sum + parseFloat(entry.hours || 0), 0);
    const avgHours = totalHours / entries.length;
    const qualityCounts = entries.reduce((acc, entry) => {
      const quality = entry.quality?.toLowerCase() || 'unknown';
      acc[quality] = (acc[quality] || 0) + 1;
      return acc;
    }, {});

    const mostCommonQuality = Object.entries(qualityCounts)
      .sort(([,a], [,b]) => b - a)[0]?.[0] || 'N/A';

    return { avgHours: avgHours.toFixed(1), mostCommonQuality, totalEntries: entries.length };
  };

  const stats = calculateSleepStats();

  const qualityToBadgeVariant = (quality) => {
    switch (quality?.toLowerCase()) {
      case 'excellent': return 'status';
      case 'good': return 'intensity';
      case 'fair': return 'meal';
      case 'poor': return 'severity';
      default: return 'status';
    }
  };

  return (
    <PageTransition className="min-h-screen bg-deep px-4 py-6 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-5xl space-y-8">
        {/* Header */}
        <PageHeader
          title="Sleep Tracker"
          subtitle="Track your sleep patterns and improve your rest"
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

        {/* Sleep Quality Hero */}
        {stats && (
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.5, ease: 'easeOut' }}
          >
            <GlassCard elevated className="flex flex-col items-center py-10">
              <p className="text-label uppercase tracking-wider text-slate-400">Average Sleep</p>
              <span
                className="mt-2 text-display"
                style={{ color: getSleepQualityColor(stats.mostCommonQuality) }}
              >
                {stats.avgHours}
              </span>
              <span className="text-lg text-slate-400">hours / night</span>
            </GlassCard>
          </motion.div>
        )}

        {/* Stats Row */}
        {stats && (
          <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
            <StatCard
              icon={<span className="text-lg">😴</span>}
              label="Avg Hours"
              value={stats.avgHours}
            />
            <StatCard
              icon={<span className="text-lg">📊</span>}
              label="Most Common Quality"
              value={stats.mostCommonQuality}
            />
            <StatCard
              icon={<span className="text-lg">📝</span>}
              label="Total Entries"
              value={stats.totalEntries}
            />
          </div>
        )}

        {/* Sleep Log Form */}
        <GlassCard>
          <h2 className="mb-5 text-lg font-semibold text-slate-100">Log Sleep</h2>
          <form onSubmit={handleSubmit} className="space-y-5">
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
              <div className="space-y-1.5">
                <label className="text-label text-slate-300">
                  <span className="mr-1.5">⏰</span>Hours Slept
                </label>
                <input
                  name="hours"
                  type="number"
                  step="0.1"
                  min="0"
                  max="24"
                  placeholder="7.5"
                  value={form.hours}
                  onChange={handleChange}
                  className="h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 placeholder-slate-500 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/40"
                  required
                />
              </div>

              <div className="space-y-1.5">
                <label className="text-label text-slate-300">
                  <span className="mr-1.5">⭐</span>Sleep Quality
                </label>
                <select
                  name="quality"
                  value={form.quality}
                  onChange={handleChange}
                  className="h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/40"
                  required
                >
                  <option value="Excellent">Excellent</option>
                  <option value="Good">Good</option>
                  <option value="Fair">Fair</option>
                  <option value="Poor">Poor</option>
                </select>
              </div>
            </div>

            <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
              <div className="space-y-1.5">
                <label className="text-label text-slate-300">
                  <span className="mr-1.5">🌙</span>Bedtime (Optional)
                </label>
                <input
                  name="bedtime"
                  type="time"
                  value={form.bedtime}
                  onChange={handleChange}
                  className="h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/40"
                />
              </div>

              <div className="space-y-1.5">
                <label className="text-label text-slate-300">
                  <span className="mr-1.5">☀️</span>Wake Time (Optional)
                </label>
                <input
                  name="wakeTime"
                  type="time"
                  value={form.wakeTime}
                  onChange={handleChange}
                  className="h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/40"
                />
              </div>
            </div>

            <div className="flex justify-end pt-2">
              <ActionButton type="submit" loading={saving} disabled={saving}>
                {saving ? 'Logging...' : 'Log Sleep'}
              </ActionButton>
            </div>
          </form>
        </GlassCard>

        {/* Sleep History */}
        <div className="space-y-4">
          <h2 className="text-lg font-semibold text-slate-100">Sleep History</h2>

          {loading ? (
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
              <LoadingSkeleton variant="card" count={4} />
            </div>
          ) : entries.length === 0 ? (
            <GlassCard>
              <EmptyState
                icon={<span className="text-2xl">😴</span>}
                title="No Sleep Data Yet"
                message="Start tracking your sleep to see your patterns and improve your rest quality."
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
                  <GlassCard className="group relative">
                    <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                      {/* Left: quality + hours */}
                      <div className="flex items-center gap-4">
                        <div
                          className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl text-2xl"
                          style={{ backgroundColor: getSleepQualityColor(entry.quality) + '18' }}
                        >
                          {getSleepQualityIcon(entry.quality)}
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="text-stat text-slate-50">{entry.hours}</span>
                            <span className="text-sm text-slate-400">hours</span>
                            <Badge variant={qualityToBadgeVariant(entry.quality)}>
                              {entry.quality}
                            </Badge>
                          </div>
                          {(entry.bedtime || entry.wake_time) && (
                            <div className="mt-1 flex items-center gap-3 text-xs text-slate-400">
                              {entry.bedtime && <span>🌙 {entry.bedtime}</span>}
                              {entry.bedtime && entry.wake_time && (
                                <span className="text-slate-600">|</span>
                              )}
                              {entry.wake_time && <span>☀️ {entry.wake_time}</span>}
                            </div>
                          )}
                        </div>
                      </div>

                      {/* Right: date + delete */}
                      <div className="flex items-center gap-3">
                        <span className="text-xs text-slate-500">{entry.entry_date}</span>
                        <button
                          onClick={() => handleDelete(entry.id)}
                          className="h-8 rounded-lg bg-error/10 px-3 text-xs font-medium text-error opacity-0 transition-all hover:bg-error/20 group-hover:opacity-100 sm:h-9"
                        >
                          Delete
                        </button>
                      </div>
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
