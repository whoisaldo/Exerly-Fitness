import React, { useState, useEffect } from 'react';
import API_CONFIG from '../config';
import {
  GlassCard,
  PageHeader,
  Badge,
  ActionButton,
  EmptyState,
  LoadingSkeleton,
  PageTransition,
} from './ui';

const fieldClasses =
  'h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 placeholder-slate-500 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/50';

export default function AdminStatusChecker() {
  const [apiHealth, setApiHealth] = useState(null);
  const [loading, setLoading] = useState(true);
  const [systemAnnouncement, setSystemAnnouncement] = useState({
    title: '',
    message: '',
    type: 'info',
    isActive: true,
  });
  const [announcements, setAnnouncements] = useState([]);
  const [submitStatus, setSubmitStatus] = useState('');

  // Fetch API health status with detailed metrics
  const fetchDetailedHealth = async () => {
    try {
      const response = await fetch(`${API_CONFIG.BASE_URL}/api/health`);
      const data = await response.json();
      setApiHealth(data);
    } catch (error) {
      setApiHealth({
        status: 'unhealthy',
        error: 'Failed to connect to API',
        timestamp: new Date().toISOString(),
      });
    } finally {
      setLoading(false);
    }
  };

  // Fetch system announcements
  const fetchAnnouncements = async () => {
    try {
      // For now, we'll use localStorage to simulate backend storage
      const stored = localStorage.getItem('systemAnnouncements');
      if (stored) {
        setAnnouncements(JSON.parse(stored));
      }
    } catch (error) {
      console.error('Failed to fetch announcements:', error);
    }
  };

  useEffect(() => {
    fetchDetailedHealth();
    fetchAnnouncements();

    // Refresh health status every 10 seconds for admin
    const interval = setInterval(fetchDetailedHealth, 10000);
    return () => clearInterval(interval);
  }, []);

  const handleAnnouncementSubmit = async (e) => {
    e.preventDefault();
    setSubmitStatus('submitting');

    try {
      const newAnnouncement = {
        ...systemAnnouncement,
        id: Date.now(),
        createdAt: new Date().toISOString(),
        createdBy: 'Admin',
      };

      const updatedAnnouncements = [newAnnouncement, ...announcements];
      setAnnouncements(updatedAnnouncements);

      // Store in localStorage (in real app, this would be sent to backend)
      localStorage.setItem('systemAnnouncements', JSON.stringify(updatedAnnouncements));

      setSubmitStatus('success');
      setSystemAnnouncement({
        title: '',
        message: '',
        type: 'info',
        isActive: true,
      });

      setTimeout(() => setSubmitStatus(''), 3000);
    } catch (error) {
      setSubmitStatus('error');
      setTimeout(() => setSubmitStatus(''), 3000);
    }
  };

  const deleteAnnouncement = (id) => {
    const updatedAnnouncements = announcements.filter((ann) => ann.id !== id);
    setAnnouncements(updatedAnnouncements);
    localStorage.setItem('systemAnnouncements', JSON.stringify(updatedAnnouncements));
  };

  const getStatusTone = (status) => {
    switch (status) {
      case 'healthy':
        return { dot: 'bg-success', text: 'text-success' };
      case 'unhealthy':
        return { dot: 'bg-error', text: 'text-error' };
      default:
        return { dot: 'bg-warning', text: 'text-warning' };
    }
  };

  const getAnnouncementBadgeVariant = (type) => {
    switch (type) {
      case 'info':
        return 'intensity';
      case 'warning':
        return 'meal';
      case 'error':
        return 'severity';
      case 'success':
        return 'status';
      default:
        return 'intensity';
    }
  };

  const statusTone = getStatusTone(apiHealth?.status);

  return (
    <PageTransition className="min-h-screen bg-deep px-4 pb-24 pt-6 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-4xl">
        <PageHeader
          title="Advanced Status Checker"
          subtitle="Admin-only system monitoring and announcements"
        />

        {/* Detailed API Health */}
        <section className="mt-8">
          <h2 className="mb-4 text-lg font-semibold text-slate-100">API Health Metrics</h2>
          <GlassCard hover={false}>
            <div className="flex items-center justify-between gap-3">
              <p className="label">Live Status</p>
              {loading ? (
                <span className="inline-flex items-center gap-2">
                  <span className="h-2 w-2 animate-pulse rounded-full bg-warning" />
                  <span className="text-xs font-semibold uppercase tracking-wider text-warning">
                    Checking
                  </span>
                </span>
              ) : (
                <span className="inline-flex items-center gap-2">
                  <span className={`h-2 w-2 rounded-full ${statusTone.dot}`} />
                  <span
                    className={`text-xs font-semibold uppercase tracking-wider ${statusTone.text}`}
                  >
                    {apiHealth?.status?.toUpperCase() || 'UNKNOWN'}
                  </span>
                </span>
              )}
            </div>

            {loading ? (
              <div className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                <LoadingSkeleton variant="table-row" count={6} />
              </div>
            ) : (
              <div className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                <div className="rounded-xl bg-surface-1 p-3">
                  <p className="label">Last Check</p>
                  <p className="mt-1 text-sm font-medium tabular-nums text-slate-100">
                    {apiHealth ? new Date(apiHealth.timestamp).toLocaleString() : 'N/A'}
                  </p>
                </div>

                <div className="rounded-xl bg-surface-1 p-3">
                  <p className="label">Uptime</p>
                  <p className="mt-1 text-sm font-medium tabular-nums text-slate-100">
                    {apiHealth?.uptime
                      ? `${Math.floor(apiHealth.uptime / 3600)}h ${Math.floor((apiHealth.uptime % 3600) / 60)}m`
                      : 'N/A'}
                  </p>
                </div>

                <div className="rounded-xl bg-surface-1 p-3">
                  <p className="label">Database</p>
                  <p className="mt-1 text-sm font-semibold">
                    <span
                      className={
                        apiHealth?.database?.status === 'connected' ? 'text-success' : 'text-error'
                      }
                    >
                      {apiHealth?.database?.status?.toUpperCase() || 'UNKNOWN'}
                    </span>
                    {apiHealth?.database?.name && (
                      <span className="ml-1.5 font-normal text-slate-500">
                        ({apiHealth.database.name})
                      </span>
                    )}
                  </p>
                </div>

                <div className="rounded-xl bg-surface-1 p-3">
                  <p className="label">Memory Usage</p>
                  <p className="mt-1 text-sm font-medium tabular-nums text-slate-100">
                    {apiHealth?.memory
                      ? `${apiHealth.memory.used} / ${apiHealth.memory.total}`
                      : 'N/A'}
                  </p>
                </div>

                <div className="rounded-xl bg-surface-1 p-3">
                  <p className="label">Version</p>
                  <p className="mt-1 text-sm font-medium tabular-nums text-slate-100">
                    {apiHealth?.version || 'N/A'}
                  </p>
                </div>

                <div className="rounded-xl bg-surface-1 p-3">
                  <p className="label">Connection State</p>
                  <p className="mt-1 text-sm font-medium text-slate-100">
                    {apiHealth?.database?.readyState === 1 ? 'Connected' : 'Disconnected'}
                  </p>
                </div>
              </div>
            )}

            <div className="mt-5 flex flex-wrap gap-3 border-t border-white/[0.06] pt-5">
              <ActionButton
                variant="secondary"
                onClick={fetchDetailedHealth}
                icon={
                  <svg
                    className="h-4 w-4"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    strokeWidth={2}
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                    />
                  </svg>
                }
              >
                Refresh Metrics
              </ActionButton>
              <ActionButton
                variant="ghost"
                onClick={() => window.open(`${API_CONFIG.BASE_URL}/api/health`, '_blank')}
                icon={
                  <svg
                    className="h-4 w-4"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    strokeWidth={2}
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
                    />
                  </svg>
                }
              >
                View Raw Data
              </ActionButton>
            </div>
          </GlassCard>
        </section>

        {/* System Announcements */}
        <section className="mt-8">
          <h2 className="mb-4 text-lg font-semibold text-slate-100">System Announcements</h2>

          {/* Create New Announcement */}
          <GlassCard hover={false}>
            <h3 className="text-sm font-semibold text-slate-100">Create New Announcement</h3>
            <form className="mt-4 space-y-4" onSubmit={handleAnnouncementSubmit}>
              <div className="grid gap-4 sm:grid-cols-2">
                <div>
                  <label className="label mb-1.5 block" htmlFor="announcement-title">
                    Title *
                  </label>
                  <input
                    type="text"
                    id="announcement-title"
                    className={fieldClasses}
                    value={systemAnnouncement.title}
                    onChange={(e) =>
                      setSystemAnnouncement({ ...systemAnnouncement, title: e.target.value })
                    }
                    placeholder="System maintenance scheduled..."
                    required
                  />
                </div>

                <div>
                  <label className="label mb-1.5 block" htmlFor="announcement-type">
                    Type
                  </label>
                  <select
                    id="announcement-type"
                    className={fieldClasses}
                    value={systemAnnouncement.type}
                    onChange={(e) =>
                      setSystemAnnouncement({ ...systemAnnouncement, type: e.target.value })
                    }
                  >
                    <option value="info">Info</option>
                    <option value="warning">Warning</option>
                    <option value="error">Error</option>
                    <option value="success">Success</option>
                  </select>
                </div>
              </div>

              <div>
                <label className="label mb-1.5 block" htmlFor="announcement-message">
                  Message *
                </label>
                <textarea
                  id="announcement-message"
                  className="w-full rounded-xl border border-border-subtle bg-surface-2 px-4 py-3 text-sm text-slate-100 placeholder-slate-500 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/50"
                  value={systemAnnouncement.message}
                  onChange={(e) =>
                    setSystemAnnouncement({ ...systemAnnouncement, message: e.target.value })
                  }
                  placeholder="System is experiencing issues and will be fixed later..."
                  rows="4"
                  required
                />
              </div>

              <label className="flex cursor-pointer items-center gap-2.5 text-sm text-slate-300">
                <input
                  type="checkbox"
                  className="h-4 w-4 accent-primary"
                  checked={systemAnnouncement.isActive}
                  onChange={(e) =>
                    setSystemAnnouncement({ ...systemAnnouncement, isActive: e.target.checked })
                  }
                />
                Active (visible to users)
              </label>

              <div className="border-t border-white/[0.06] pt-5">
                <ActionButton
                  type="submit"
                  loading={submitStatus === 'submitting'}
                  disabled={submitStatus === 'submitting'}
                  icon={
                    <svg
                      className="h-4 w-4"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      strokeWidth={2}
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        d="M11 5.882V19.24a1.76 1.76 0 01-3.417.592l-2.147-6.15M18 13a3 3 0 100-6M5.436 13.683A4.001 4.001 0 017 6h1.832c4.1 0 7.625-1.234 9.168-3v14c-1.543-1.766-5.067-3-9.168-3H7a3.988 3.988 0 01-1.564-.317z"
                      />
                    </svg>
                  }
                >
                  {submitStatus === 'submitting' ? 'Publishing...' : 'Publish Announcement'}
                </ActionButton>
              </div>

              {submitStatus === 'success' && (
                <div className="flex items-center gap-2 rounded-xl border border-success/20 bg-success/10 p-3 text-sm text-success">
                  <svg
                    className="h-4 w-4 shrink-0"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    strokeWidth={2}
                  >
                    <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                  </svg>
                  Announcement published successfully!
                </div>
              )}

              {submitStatus === 'error' && (
                <div className="flex items-center gap-2 rounded-xl border border-error/20 bg-error/10 p-3 text-sm text-error">
                  <svg
                    className="h-4 w-4 shrink-0"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    strokeWidth={2}
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                    />
                  </svg>
                  Failed to publish announcement. Please try again.
                </div>
              )}
            </form>
          </GlassCard>

          {/* Existing Announcements */}
          <div className="mt-6">
            <h3 className="mb-3 text-sm font-semibold text-slate-100">Recent Announcements</h3>
            {announcements.length === 0 ? (
              <GlassCard hover={false}>
                <EmptyState
                  icon={
                    <svg
                      className="h-6 w-6"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      strokeWidth={2}
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        d="M11 5.882V19.24a1.76 1.76 0 01-3.417.592l-2.147-6.15M18 13a3 3 0 100-6M5.436 13.683A4.001 4.001 0 017 6h1.832c4.1 0 7.625-1.234 9.168-3v14c-1.543-1.766-5.067-3-9.168-3H7a3.988 3.988 0 01-1.564-.317z"
                      />
                    </svg>
                  }
                  title="No announcements yet"
                  message="Create one above!"
                />
              </GlassCard>
            ) : (
              <div className="space-y-3">
                {announcements.map((announcement) => (
                  <GlassCard key={announcement.id} hover={false}>
                    <div className="flex items-start justify-between gap-3">
                      <div className="flex flex-wrap items-center gap-2.5">
                        <Badge variant={getAnnouncementBadgeVariant(announcement.type)}>
                          {announcement.type.toUpperCase()}
                        </Badge>
                        <span className="inline-flex items-center gap-1.5 text-xs text-slate-400">
                          <span
                            className={`h-2 w-2 rounded-full ${announcement.isActive ? 'bg-success' : 'bg-error'}`}
                          />
                          {announcement.isActive ? 'Active' : 'Inactive'}
                        </span>
                      </div>
                      <button
                        type="button"
                        onClick={() => deleteAnnouncement(announcement.id)}
                        title="Delete announcement"
                        aria-label="Delete announcement"
                        className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-slate-500 transition-colors hover:bg-error/10 hover:text-error"
                      >
                        <svg
                          className="h-4 w-4"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke="currentColor"
                          strokeWidth={2}
                        >
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                          />
                        </svg>
                      </button>
                    </div>

                    <h4 className="mt-3 text-sm font-semibold text-slate-100">
                      {announcement.title}
                    </h4>
                    <p className="mt-1 text-sm leading-relaxed text-slate-400">
                      {announcement.message}
                    </p>

                    <div className="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-xs text-slate-500">
                      <span className="tabular-nums">
                        Created: {new Date(announcement.createdAt).toLocaleString()}
                      </span>
                      <span>By: {announcement.createdBy}</span>
                    </div>
                  </GlassCard>
                ))}
              </div>
            )}
          </div>
        </section>

        {/* Admin Tools */}
        <section className="mt-8">
          <h2 className="mb-4 text-lg font-semibold text-slate-100">Admin Tools</h2>
          <GlassCard hover={false}>
            <div className="flex flex-wrap gap-3">
              <ActionButton
                variant="secondary"
                onClick={() => window.open('/#/status-check', '_blank')}
                icon={
                  <svg
                    className="h-4 w-4"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    strokeWidth={2}
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                    />
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M2.458 12C3.732 7.943 7.523 4.5 12 4.5c4.478 0 8.268 3.443 9.542 7.5-1.274 4.057-5.064 7.5-9.542 7.5-4.477 0-8.268-3.443-9.542-7.5z"
                    />
                  </svg>
                }
              >
                View Public Status Page
              </ActionButton>
              <ActionButton
                variant="secondary"
                onClick={() => window.open(`${API_CONFIG.BASE_URL}/api/health`, '_blank')}
                icon={
                  <svg
                    className="h-4 w-4"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    strokeWidth={2}
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"
                    />
                  </svg>
                }
              >
                API Health JSON
              </ActionButton>
              <ActionButton
                variant="secondary"
                onClick={() => {
                  localStorage.removeItem('systemAnnouncements');
                  setAnnouncements([]);
                }}
                icon={
                  <svg
                    className="h-4 w-4"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    strokeWidth={2}
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                    />
                  </svg>
                }
              >
                Clear All Announcements
              </ActionButton>
            </div>
          </GlassCard>
        </section>
      </div>
    </PageTransition>
  );
}
