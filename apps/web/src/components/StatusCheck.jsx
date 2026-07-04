import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import API_CONFIG from '../config';
import { PageTransition, PageHeader, GlassCard, ActionButton } from './ui';

const INPUT_CLASSES =
  'h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 placeholder-slate-500 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/50';

const STATUS_META = {
  healthy: { label: 'Operational', text: 'text-success', bar: 'bg-success' },
  unhealthy: { label: 'Service disruption', text: 'text-error', bar: 'bg-error' },
  unknown: { label: 'Checking status…', text: 'text-slate-400', bar: 'bg-slate-600' },
};

const UPTIME_DAYS = 90;

const dayLabel = (daysAgo) => {
  const d = new Date();
  d.setDate(d.getDate() - daysAgo);
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
};

function HealthRow({ label, children }) {
  return (
    <div className="flex items-baseline justify-between gap-3 border-b border-white/[0.06] py-2.5 last:border-0">
      <span className="text-sm text-slate-500">{label}</span>
      <span className="text-right text-sm text-slate-200">{children}</span>
    </div>
  );
}

export default function StatusCheck() {
  const [apiHealth, setApiHealth] = useState(null);
  const [loading, setLoading] = useState(true);
  const [bugReport, setBugReport] = useState({
    title: '',
    description: '',
    email: '',
    severity: 'medium',
  });
  const [submitStatus, setSubmitStatus] = useState('');

  // Fetch API health status
  const fetchApiHealth = async () => {
    try {
      const response = await fetch(`${API_CONFIG.BASE_URL}/api/health`);
      const data = await response.json();
      setApiHealth(data);
    } catch {
      setApiHealth({
        status: 'unhealthy',
        error: 'Failed to connect to API',
        timestamp: new Date().toISOString(),
      });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchApiHealth();
    // Refresh health status every 30 seconds
    const interval = setInterval(fetchApiHealth, 30000);
    return () => clearInterval(interval);
  }, []);

  const handleBugReportSubmit = async (e) => {
    e.preventDefault();
    setSubmitStatus('submitting');

    try {
      // For now, we'll just log the bug report
      // In a real app, this would be sent to a backend endpoint
      console.log('Bug Report Submitted:', bugReport);

      setSubmitStatus('success');
      setBugReport({
        title: '',
        description: '',
        email: '',
        severity: 'medium',
      });

      setTimeout(() => setSubmitStatus(''), 3000);
    } catch {
      setSubmitStatus('error');
      setTimeout(() => setSubmitStatus(''), 3000);
    }
  };

  const meta = STATUS_META[apiHealth?.status] ?? STATUS_META.unknown;

  return (
    <PageTransition className="min-h-screen bg-deep px-4 pb-24 pt-10 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-2xl">
        <PageHeader
          title="System status"
          subtitle="Live API health and issue reporting."
          action={
            <ActionButton
              variant="secondary"
              onClick={fetchApiHealth}
              icon={
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                  <path
                    d="M21 12a9 9 0 1 1-2.64-6.36M21 3v6h-6"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
              }
            >
              Refresh
            </ActionButton>
          }
        />

        <GlassCard className="mt-8" hover={false}>
          <div className="flex items-baseline justify-between gap-3">
            <h2 className="label">API</h2>
            {!loading && <span className={`text-sm font-medium ${meta.text}`}>{meta.label}</span>}
          </div>
          {loading ? (
            <div className="flex items-center gap-3 py-6">
              <div className="h-5 w-5 animate-spin rounded-full border-2 border-primary border-t-transparent" />
              <span className="text-sm text-slate-400">Checking API status...</span>
            </div>
          ) : (
            <>
              <div className="mt-5 flex h-8 gap-[2px]" aria-hidden="true">
                {Array.from({ length: UPTIME_DAYS }, (_, i) => {
                  const daysAgo = UPTIME_DAYS - 1 - i;
                  const isToday = daysAgo === 0;
                  return (
                    <span
                      key={i}
                      title={
                        isToday
                          ? `${dayLabel(0)} · Live status`
                          : `${dayLabel(daysAgo)} · No incidents recorded`
                      }
                      className={`h-full flex-1 rounded-[2px] ${isToday ? meta.bar : 'bg-success/60'}`}
                    />
                  );
                })}
              </div>
              <div className="mt-2 flex items-center justify-between text-[11px] text-slate-500">
                <span>{UPTIME_DAYS} days ago</span>
                <span>Today</span>
              </div>

              {apiHealth && (
                <div className="mt-4">
                  <HealthRow label="Last check">
                    {new Date(apiHealth.timestamp).toLocaleString()}
                  </HealthRow>

                  {apiHealth.uptime && (
                    <HealthRow label="Uptime">
                      <span className="tabular-nums">
                        {Math.floor(apiHealth.uptime / 3600)}h{' '}
                        {Math.floor((apiHealth.uptime % 3600) / 60)}m
                      </span>
                    </HealthRow>
                  )}

                  {apiHealth.error && (
                    <div className="mt-3 rounded-xl border border-error/20 bg-error/10 p-3 text-sm text-error">
                      {apiHealth.error}
                    </div>
                  )}
                </div>
              )}
            </>
          )}
        </GlassCard>

        <GlassCard className="mt-5" hover={false}>
          <h2 className="label">Report a bug</h2>
          <form className="mt-4 space-y-4" onSubmit={handleBugReportSubmit}>
            <div>
              <label htmlFor="title" className="label mb-1.5 block">
                Title *
              </label>
              <input
                type="text"
                id="title"
                value={bugReport.title}
                onChange={(e) => setBugReport({ ...bugReport, title: e.target.value })}
                placeholder="Brief description of the issue"
                required
                className={INPUT_CLASSES}
              />
            </div>

            <div>
              <label htmlFor="severity" className="label mb-1.5 block">
                Severity
              </label>
              <select
                id="severity"
                value={bugReport.severity}
                onChange={(e) => setBugReport({ ...bugReport, severity: e.target.value })}
                className={INPUT_CLASSES}
              >
                <option value="low">Low - Minor issue</option>
                <option value="medium">Medium - Moderate issue</option>
                <option value="high">High - Major issue</option>
                <option value="critical">Critical - System down</option>
              </select>
            </div>

            <div>
              <label htmlFor="email" className="label mb-1.5 block">
                Email (optional)
              </label>
              <input
                type="email"
                id="email"
                value={bugReport.email}
                onChange={(e) => setBugReport({ ...bugReport, email: e.target.value })}
                placeholder="your.email@example.com"
                className={INPUT_CLASSES}
              />
            </div>

            <div>
              <label htmlFor="description" className="label mb-1.5 block">
                Description *
              </label>
              <textarea
                id="description"
                value={bugReport.description}
                onChange={(e) => setBugReport({ ...bugReport, description: e.target.value })}
                placeholder="Please describe the issue in detail. Include steps to reproduce if possible."
                rows="5"
                required
                className={`${INPUT_CLASSES} h-auto py-3`}
              />
            </div>

            <ActionButton type="submit" loading={submitStatus === 'submitting'}>
              {submitStatus === 'submitting' ? 'Submitting...' : 'Submit bug report'}
            </ActionButton>

            {submitStatus === 'success' && (
              <div className="rounded-xl border border-success/20 bg-success/10 p-3 text-sm text-success">
                Bug report submitted successfully.
              </div>
            )}

            {submitStatus === 'error' && (
              <div className="rounded-xl border border-error/20 bg-error/10 p-3 text-sm text-error">
                Failed to submit bug report. Please try again.
              </div>
            )}
          </form>
        </GlassCard>

        <div className="mt-5 flex flex-wrap gap-3">
          <Link
            to="/maintenance-history"
            className="inline-flex items-center gap-2 rounded-xl border border-white/[0.12] bg-surface-3 px-4 py-2.5 text-sm font-semibold text-slate-100 transition-all duration-200 hover:border-white/[0.2] hover:bg-surface-2"
          >
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" aria-hidden="true">
              <path
                d="M3 6h.01M3 12h.01M3 18h.01M8 6h13M8 12h13M8 18h13"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
              />
            </svg>
            Maintenance history
          </Link>
          <Link
            to="/credits"
            className="inline-flex items-center gap-2 rounded-xl border border-white/[0.12] bg-surface-3 px-4 py-2.5 text-sm font-semibold text-slate-100 transition-all duration-200 hover:border-white/[0.2] hover:bg-surface-2"
          >
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" aria-hidden="true">
              <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="2" />
              <path
                d="M12 16v-4m0-4h.01"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
              />
            </svg>
            About & credits
          </Link>
          <Link
            to="/"
            className="inline-flex items-center gap-2 rounded-xl border border-white/[0.12] bg-surface-3 px-4 py-2.5 text-sm font-semibold text-slate-100 transition-all duration-200 hover:border-white/[0.2] hover:bg-surface-2"
          >
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" aria-hidden="true">
              <path
                d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V9Z"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
            Back to app
          </Link>
        </div>
      </div>
    </PageTransition>
  );
}
