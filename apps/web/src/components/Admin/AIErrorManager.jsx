import React, { useState, useEffect } from 'react';
import API_CONFIG from '../../config';
import {
  GlassCard,
  PageHeader,
  ActionButton,
  EmptyState,
  LoadingSkeleton,
  PageTransition,
} from '../ui';

const { BASE_URL } = API_CONFIG;

const fieldClasses =
  'h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/50';

const pillBase =
  'inline-flex items-center gap-1 rounded-full border px-2.5 py-0.5 text-xs font-medium';

const AIErrorManager = () => {
  const [errors, setErrors] = useState([]);
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [selectedError, setSelectedError] = useState(null);
  const [filters, setFilters] = useState({
    status: '',
    severity: '',
    errorType: '',
  });
  const [pagination, setPagination] = useState({
    page: 1,
    limit: 20,
    total: 0,
    pages: 0,
  });

  useEffect(() => {
    fetchErrors();
    fetchStats();
  }, [pagination.page, filters]);

  const fetchErrors = async () => {
    try {
      const token = localStorage.getItem('token');
      const queryParams = new URLSearchParams({
        page: pagination.page,
        limit: pagination.limit,
        ...filters,
      });

      const response = await fetch(`${BASE_URL}/api/admin/ai-errors?${queryParams}`, {
        headers: { Authorization: `Bearer ${token}` },
      });

      if (response.ok) {
        const data = await response.json();
        setErrors(data.errors);
        setPagination((prev) => ({
          ...prev,
          ...data.pagination,
        }));
      }
    } catch (error) {
      console.error('Error fetching AI errors:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchStats = async () => {
    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`${BASE_URL}/api/admin/ai-errors/stats`, {
        headers: { Authorization: `Bearer ${token}` },
      });

      if (response.ok) {
        const data = await response.json();
        setStats(data);
      }
    } catch (error) {
      console.error('Error fetching AI error stats:', error);
    }
  };

  const updateErrorStatus = async (errorId, status, adminNotes = '') => {
    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`${BASE_URL}/api/admin/ai-errors/${errorId}/status`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ status, adminNotes }),
      });

      if (response.ok) {
        fetchErrors();
        setSelectedError(null);
      }
    } catch (error) {
      console.error('Error updating error status:', error);
    }
  };

  const deleteError = async (errorId) => {
    if (!window.confirm('Are you sure you want to delete this error?')) return;

    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`${BASE_URL}/api/admin/ai-errors/${errorId}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` },
      });

      if (response.ok) {
        fetchErrors();
        setSelectedError(null);
      }
    } catch (error) {
      console.error('Error deleting error:', error);
    }
  };

  const cleanupOldErrors = async () => {
    if (
      !window.confirm('Are you sure you want to clean up old errors? This action cannot be undone.')
    )
      return;

    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`${BASE_URL}/api/admin/ai-errors/cleanup`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ daysOld: 30 }),
      });

      if (response.ok) {
        const data = await response.json();
        alert(data.message);
        fetchErrors();
        fetchStats();
      }
    } catch (error) {
      console.error('Error cleaning up errors:', error);
    }
  };

  const getSeverityClasses = (severity) => {
    switch (severity) {
      case 'CRITICAL':
        return 'bg-error/15 text-error border-error/20';
      case 'HIGH':
        return 'bg-warning/15 text-warning border-warning/20';
      case 'MEDIUM':
        return 'bg-primary/15 text-primary-bright border-primary/20';
      case 'LOW':
        return 'bg-success/15 text-success border-success/20';
      default:
        return 'bg-white/[0.06] text-slate-400 border-white/[0.1]';
    }
  };

  const getStatusClasses = (status) => {
    switch (status) {
      case 'OPEN':
        return 'bg-error/15 text-error border-error/20';
      case 'INVESTIGATING':
        return 'bg-warning/15 text-warning border-warning/20';
      case 'RESOLVED':
        return 'bg-success/15 text-success border-success/20';
      case 'IGNORED':
        return 'bg-white/[0.06] text-slate-400 border-white/[0.1]';
      default:
        return 'bg-white/[0.06] text-slate-400 border-white/[0.1]';
    }
  };

  const formatDate = (dateString) => {
    if (!dateString) return 'Unknown';
    const d = new Date(dateString);
    return Number.isNaN(d.getTime()) ? 'Invalid date' : d.toLocaleString();
  };

  if (loading) {
    return (
      <PageTransition className="min-h-screen bg-deep px-4 pb-24 pt-6 sm:px-6 lg:px-8">
        <div className="mx-auto max-w-5xl">
          <PageHeader title="AI Error Management" subtitle="Monitor and triage AI errors" />
          <div className="mt-6 grid gap-4 sm:grid-cols-3">
            <LoadingSkeleton variant="stat" count={3} />
          </div>
          <div className="mt-6 space-y-3">
            <LoadingSkeleton variant="card" count={3} />
          </div>
        </div>
      </PageTransition>
    );
  }

  return (
    <PageTransition className="min-h-screen bg-deep px-4 pb-24 pt-6 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-5xl">
        <PageHeader
          title="AI Error Management"
          subtitle="Monitor and triage AI errors"
          action={
            <div className="flex flex-wrap gap-2">
              <ActionButton
                variant="ghost"
                onClick={cleanupOldErrors}
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
                Cleanup Old Errors
              </ActionButton>
              <ActionButton
                variant="secondary"
                onClick={fetchErrors}
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
                Refresh
              </ActionButton>
            </div>
          }
        />

        {/* Stats Overview */}
        {stats && (
          <div className="mt-6 grid gap-4 sm:grid-cols-3">
            <GlassCard>
              <p className="label">Total Errors</p>
              <p className="mt-2 text-3xl font-bold tabular-nums text-slate-50">
                {stats.totalErrors}
              </p>
            </GlassCard>
            <GlassCard>
              <p className="label">Open Errors</p>
              <p className="mt-2 text-3xl font-bold tabular-nums text-warning">
                {stats.openErrors}
              </p>
            </GlassCard>
            <GlassCard>
              <p className="label">Critical Errors</p>
              <p className="mt-2 text-3xl font-bold tabular-nums text-error">
                {stats.criticalErrors}
              </p>
            </GlassCard>
          </div>
        )}

        {/* Filters */}
        <GlassCard hover={false} className="mt-6">
          <div className="grid gap-4 sm:grid-cols-3">
            <div>
              <label className="label mb-1.5 block" htmlFor="filter-status">
                Status
              </label>
              <select
                id="filter-status"
                className={fieldClasses}
                value={filters.status}
                onChange={(e) => setFilters((prev) => ({ ...prev, status: e.target.value }))}
              >
                <option value="">All</option>
                <option value="OPEN">Open</option>
                <option value="INVESTIGATING">Investigating</option>
                <option value="RESOLVED">Resolved</option>
                <option value="IGNORED">Ignored</option>
              </select>
            </div>
            <div>
              <label className="label mb-1.5 block" htmlFor="filter-severity">
                Severity
              </label>
              <select
                id="filter-severity"
                className={fieldClasses}
                value={filters.severity}
                onChange={(e) => setFilters((prev) => ({ ...prev, severity: e.target.value }))}
              >
                <option value="">All</option>
                <option value="CRITICAL">Critical</option>
                <option value="HIGH">High</option>
                <option value="MEDIUM">Medium</option>
                <option value="LOW">Low</option>
              </select>
            </div>
            <div>
              <label className="label mb-1.5 block" htmlFor="filter-type">
                Type
              </label>
              <select
                id="filter-type"
                className={fieldClasses}
                value={filters.errorType}
                onChange={(e) => setFilters((prev) => ({ ...prev, errorType: e.target.value }))}
              >
                <option value="">All</option>
                <option value="API_ERROR">API Error</option>
                <option value="RATE_LIMIT">Rate Limit</option>
                <option value="VALIDATION_ERROR">Validation Error</option>
                <option value="NETWORK_ERROR">Network Error</option>
                <option value="AI_MODEL_ERROR">AI Model Error</option>
                <option value="UNKNOWN_ERROR">Unknown Error</option>
              </select>
            </div>
          </div>
        </GlassCard>

        {/* Errors List */}
        <div className="mt-6">
          {errors.length === 0 ? (
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
                      d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"
                    />
                  </svg>
                }
                title="No errors found"
                message="Errors logged by the AI services will show up here."
              />
            </GlassCard>
          ) : (
            <div className="space-y-3">
              {errors.map((error) => (
                <button
                  key={error._id}
                  type="button"
                  onClick={() => setSelectedError(error)}
                  className="glass w-full p-4 text-left transition-colors hover:border-white/[0.14] hover:bg-surface-3"
                >
                  <div className="flex flex-wrap items-start justify-between gap-2">
                    <div className="flex min-w-0 flex-wrap items-baseline gap-x-2 gap-y-1">
                      <span className="text-sm font-semibold text-slate-100">
                        {error.errorType}
                      </span>
                      <span className="font-mono text-xs text-slate-500">{error.errorCode}</span>
                    </div>
                    <div className="flex shrink-0 gap-1.5">
                      <span className={`${pillBase} ${getSeverityClasses(error.severity)}`}>
                        {error.severity}
                      </span>
                      <span className={`${pillBase} ${getStatusClasses(error.status)}`}>
                        {error.status}
                      </span>
                    </div>
                  </div>
                  <p className="mt-2 break-words text-sm text-slate-400">{error.errorMessage}</p>
                  <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-slate-500">
                    <span>{error.email}</span>
                    <span className="tabular-nums">{formatDate(error.created_at)}</span>
                  </div>
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Pagination */}
        {pagination.pages > 1 && (
          <div className="mt-6 flex items-center justify-center gap-4">
            <ActionButton
              variant="secondary"
              onClick={() => setPagination((prev) => ({ ...prev, page: prev.page - 1 }))}
              disabled={pagination.page === 1}
            >
              Previous
            </ActionButton>
            <span className="text-sm tabular-nums text-slate-400">
              Page {pagination.page} of {pagination.pages}
            </span>
            <ActionButton
              variant="secondary"
              onClick={() => setPagination((prev) => ({ ...prev, page: prev.page + 1 }))}
              disabled={pagination.page === pagination.pages}
            >
              Next
            </ActionButton>
          </div>
        )}

        {/* Error Detail Modal */}
        {selectedError && (
          <div
            className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 backdrop-blur-sm"
            onClick={() => setSelectedError(null)}
          >
            <div
              className="max-h-[90vh] w-full max-w-2xl overflow-y-auto"
              onClick={(e) => e.stopPropagation()}
            >
              <GlassCard elevated hover={false} className="!p-6">
                <div className="mb-5 flex items-center justify-between">
                  <h2 className="text-lg font-semibold text-slate-100">Error Details</h2>
                  <button
                    type="button"
                    onClick={() => setSelectedError(null)}
                    aria-label="Close"
                    className="flex h-8 w-8 items-center justify-center rounded-lg text-slate-400 transition-colors hover:bg-white/5 hover:text-slate-100"
                  >
                    <svg
                      className="h-5 w-5"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      strokeWidth={2}
                    >
                      <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>

                <div>
                  <div className="flex justify-between gap-3 border-b border-white/[0.06] py-2">
                    <span className="shrink-0 text-sm text-slate-500">Error Type</span>
                    <span className="text-right text-sm text-slate-200">
                      {selectedError.errorType}
                    </span>
                  </div>
                  <div className="flex justify-between gap-3 border-b border-white/[0.06] py-2">
                    <span className="shrink-0 text-sm text-slate-500">Error Code</span>
                    <span className="break-all text-right font-mono text-xs text-slate-200">
                      {selectedError.errorCode}
                    </span>
                  </div>
                  <div className="flex items-center justify-between gap-3 border-b border-white/[0.06] py-2">
                    <span className="shrink-0 text-sm text-slate-500">Severity</span>
                    <span className={`${pillBase} ${getSeverityClasses(selectedError.severity)}`}>
                      {selectedError.severity}
                    </span>
                  </div>
                  <div className="flex items-center justify-between gap-3 border-b border-white/[0.06] py-2">
                    <span className="shrink-0 text-sm text-slate-500">Status</span>
                    <span className={`${pillBase} ${getStatusClasses(selectedError.status)}`}>
                      {selectedError.status}
                    </span>
                  </div>
                  <div className="flex justify-between gap-3 border-b border-white/[0.06] py-2">
                    <span className="shrink-0 text-sm text-slate-500">User</span>
                    <span className="break-all text-right text-sm text-slate-200">
                      {selectedError.email}
                    </span>
                  </div>
                  <div className="flex justify-between gap-3 border-b border-white/[0.06] py-2">
                    <span className="shrink-0 text-sm text-slate-500">Session ID</span>
                    <span className="break-all text-right font-mono text-xs text-slate-200">
                      {selectedError.sessionId}
                    </span>
                  </div>
                  <div className="flex justify-between gap-3 py-2">
                    <span className="shrink-0 text-sm text-slate-500">Created</span>
                    <span className="text-right text-sm tabular-nums text-slate-200">
                      {formatDate(selectedError.created_at)}
                    </span>
                  </div>
                </div>

                <div className="mt-4">
                  <p className="label">Message</p>
                  <p className="mt-1.5 break-words text-sm leading-relaxed text-slate-200">
                    {selectedError.errorMessage}
                  </p>
                </div>

                {selectedError.stackTrace && (
                  <div className="mt-4">
                    <p className="label">Stack Trace</p>
                    <pre className="mt-1.5 whitespace-pre-wrap break-words rounded-xl bg-surface-1 p-3 font-mono text-xs text-slate-300">
                      {selectedError.stackTrace}
                    </pre>
                  </div>
                )}

                {selectedError.adminNotes && (
                  <div className="mt-4">
                    <p className="label">Admin Notes</p>
                    <p className="mt-1.5 break-words text-sm text-slate-200">
                      {selectedError.adminNotes}
                    </p>
                  </div>
                )}

                <div className="mt-6 flex flex-col gap-3 border-t border-white/[0.06] pt-5 sm:flex-row sm:items-end sm:justify-between">
                  <div className="w-full sm:w-56">
                    <label className="label mb-1.5 block" htmlFor="update-error-status">
                      Update Status
                    </label>
                    <select
                      id="update-error-status"
                      className={fieldClasses}
                      onChange={(e) => updateErrorStatus(selectedError._id, e.target.value)}
                      value={selectedError.status}
                    >
                      <option value="OPEN">Open</option>
                      <option value="INVESTIGATING">Investigating</option>
                      <option value="RESOLVED">Resolved</option>
                      <option value="IGNORED">Ignored</option>
                    </select>
                  </div>
                  <button
                    type="button"
                    onClick={() => deleteError(selectedError._id)}
                    className="inline-flex h-11 items-center justify-center gap-2 rounded-xl border border-error/20 bg-error/10 px-5 text-sm font-semibold text-error transition-colors hover:bg-error/20"
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
                    Delete
                  </button>
                </div>
              </GlassCard>
            </div>
          </div>
        )}
      </div>
    </PageTransition>
  );
};

export default AIErrorManager;
