// frontend/src/components/Admin/Admin.jsx
import React, { useEffect, useState, useMemo, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { GlassCard, StatCard, PageHeader, PageTransition, ActionButton, Badge, DataTable, EmptyState, LoadingSkeleton } from '../ui';
import API_CONFIG from '../../config';

const BASE_URL = API_CONFIG.BASE_URL;

// Enhanced JWT decoder
function decodeJWT(token) {
  try {
    const base64 = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    return JSON.parse(atob(base64));
  } catch {
    return null;
  }
}

export default function Admin() {
  const navigate = useNavigate();
  const [users, setUsers] = useState([]);
  const [selectedEmail, setSelectedEmail] = useState('');
  const [entries, setEntries] = useState({ activities: [], food: [], sleep: [] });
  const [loading, setLoading] = useState(true);
  const [usersLoading, setUsersLoading] = useState(true);
  const [entriesLoading, setEntriesLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [apiHealth, setApiHealth] = useState(null);
  const [activeTab, setActiveTab] = useState('users');

  const token = localStorage.getItem('token') || '';
  const me = useMemo(() => decodeJWT(token) || {}, [token]);

  // Fetch API health status
  const fetchApiHealth = useCallback(async () => {
    try {
      const response = await fetch(`${BASE_URL}/api/health`);
      const data = await response.json();
      setApiHealth(data);
    } catch (error) {
      setApiHealth({
        status: 'unhealthy',
        error: 'Failed to connect to API',
        timestamp: new Date().toISOString()
      });
    }
  }, [BASE_URL]);

  // Load users list (admin-only)
  useEffect(() => {
    if (!token) {
      navigate('/');
      return;
    }

    if (!me?.is_admin) {
      navigate('/dashboard');
      return;
    }

    setUsersLoading(true);
    setError('');

    // Fetch API health status
    fetchApiHealth();

    fetch(`${BASE_URL}/api/admin/users`, {
      headers: { Authorization: 'Bearer ' + token }
    })
      .then(r => {
        if (r.status === 401) {
          navigate('/');
          return Promise.reject('Unauthorized');
        }
        if (r.status === 403) {
          navigate('/dashboard');
          return Promise.reject('Not admin');
        }
        return r.json();
      })
      .then(list => {
        const userList = list || [];
        setUsers(userList);
        if (userList.length > 0 && !selectedEmail) {
          setSelectedEmail(userList[0].email);
        }
      })
      .catch(err => {
        console.error('Failed to load users:', err);
        setError('Failed to load users. Please try again.');
      })
      .finally(() => setUsersLoading(false));
  }, [navigate, token, me, selectedEmail]);

  // Load selected user's entries
  useEffect(() => {
    if (!selectedEmail) {
      setEntries({ activities: [], food: [], sleep: [] });
      return;
    }

    setEntriesLoading(true);
    setError('');

    fetch(`${BASE_URL}/api/admin/user/${encodeURIComponent(selectedEmail)}/entries`, {
      headers: { Authorization: 'Bearer ' + token }
    })
      .then(r => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        return r.json();
      })
      .then(data => {
        setEntries({
          activities: data.activities || [],
          food: data.food || [],
          sleep: data.sleep || []
        });
      })
      .catch(err => {
        console.error('Failed to load entries:', err);
        setError('Failed to load user entries. Please try again.');
        setEntries({ activities: [], food: [], sleep: [] });
      })
      .finally(() => setEntriesLoading(false));
  }, [selectedEmail, token]);

  const totals = useMemo(() => {
    const burned = entries.activities.reduce((s, a) => s + Number(a.calories || 0), 0);
    const consumed = entries.food.reduce((s, f) => s + Number(f.calories || 0), 0);
    const sleepHrs = entries.sleep.reduce((s, sl) => s + Number(sl.hours || 0), 0);
    const totalEntries = entries.activities.length + entries.food.length + entries.sleep.length;

    return {
      workouts: entries.activities.length,
      burned,
      consumed,
      sleepHrs,
      totalEntries
    };
  }, [entries]);

  const resetTodayForUser = async () => {
    if (!selectedEmail) return;

    const ok = window.confirm(
      `Reset today's logs for ${selectedEmail}?\n\nThis will delete all activities, food, and sleep entries for today. This action cannot be undone.`
    );

    if (!ok) return;

    try {
      setError('');
      setSuccess('');

      const res = await fetch(`${BASE_URL}/api/admin/user/${encodeURIComponent(selectedEmail)}/reset-today`, {
        method: 'POST',
        headers: { Authorization: 'Bearer ' + token }
      });

      if (!res.ok) throw new Error(`HTTP ${res.status}`);

      const data = await res.json();
      setSuccess(`Successfully reset today's data for ${selectedEmail}. Removed ${data.counts.activities + data.counts.food + data.counts.sleep} entries.`);

      // Refresh entries
      const entriesRes = await fetch(`${BASE_URL}/api/admin/user/${encodeURIComponent(selectedEmail)}/entries`, {
        headers: { Authorization: 'Bearer ' + token }
      });

      if (entriesRes.ok) {
        const newEntries = await entriesRes.json();
        setEntries({
          activities: newEntries.activities || [],
          food: newEntries.food || [],
          sleep: newEntries.sleep || []
        });
      }
    } catch (err) {
      console.error('Reset failed:', err);
      setError('Failed to reset today\'s data. Please try again.');
    }
  };

  const clearMessages = () => {
    setError('');
    setSuccess('');
  };

  const selectedUser = useMemo(() =>
    users.find(u => u.email === selectedEmail), [users, selectedEmail]
  );

  if (!me?.is_admin) {
    return null; // Will redirect via useEffect
  }

  const tabs = [
    { id: 'users', label: 'Users' },
    { id: 'ai-errors', label: 'AI Errors' },
    { id: 'system', label: 'System' },
  ];

  const userTableColumns = [
    {
      key: 'email',
      label: 'User',
      render: (row) => (
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-full bg-gradient-primary flex items-center justify-center shrink-0">
            <span className="text-white text-xs font-bold">
              {row.name ? row.name.charAt(0).toUpperCase() : 'U'}
            </span>
          </div>
          <div className="min-w-0">
            <p className="text-white text-sm font-medium truncate">{row.name || 'Unnamed'}</p>
            <p className="text-white/40 text-xs truncate">{row.email}</p>
          </div>
        </div>
      ),
    },
    {
      key: 'created_at',
      label: 'Joined',
      sortable: true,
      render: (row) => (
        <span className="text-white/50 text-sm">
          {row.created_at ? new Date(row.created_at).toLocaleDateString() : '--'}
        </span>
      ),
    },
    {
      key: 'is_admin',
      label: 'Role',
      render: (row) => (
        <Badge variant={row.is_admin ? 'intensity' : 'status'}>
          {row.is_admin ? 'Admin' : 'User'}
        </Badge>
      ),
    },
    {
      key: 'actions',
      label: '',
      render: (row) => (
        <button
          onClick={(e) => {
            e.stopPropagation();
            setSelectedEmail(row.email);
          }}
          className="text-primary text-xs hover:text-primary-bright transition-colors h-8 px-3 rounded-lg hover:bg-primary/10"
        >
          View
        </button>
      ),
    },
  ];

  return (
    <PageTransition>
      <div className="min-h-screen bg-deep px-4 py-6 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto">
          {/* Header */}
          <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4 mb-8">
            <div>
              <div className="flex items-center gap-3 mb-2">
                <PageHeader title="Admin Console" />
                <Badge variant="intensity">Admin</Badge>
              </div>
              <p className="text-white/40 text-sm">Monitor user activity, view logs, and manage data</p>
            </div>

            <div className="flex items-center gap-2 shrink-0">
              <ActionButton
                variant="ghost"
                onClick={() => navigate('/dashboard/admin/ai-errors')}
              >
                AI Errors
              </ActionButton>
              <ActionButton
                variant="ghost"
                onClick={() => navigate('/dashboard/admin/status')}
              >
                Status
              </ActionButton>
              <ActionButton
                variant="secondary"
                onClick={() => navigate('/dashboard')}
                icon={
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
                  </svg>
                }
              >
                Back
              </ActionButton>
            </div>
          </div>

          {/* Messages */}
          <AnimatePresence>
            {error && (
              <motion.div
                initial={{ opacity: 0, y: -12 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -12 }}
                className="mb-6 rounded-xl border border-error/20 bg-error/10 px-4 py-3 flex items-center justify-between"
              >
                <span className="text-error text-sm font-medium">{error}</span>
                <button onClick={clearMessages} className="text-error/60 hover:text-error ml-3 h-6 w-6 flex items-center justify-center">
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </motion.div>
            )}
          </AnimatePresence>

          <AnimatePresence>
            {success && (
              <motion.div
                initial={{ opacity: 0, y: -12 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -12 }}
                className="mb-6 rounded-xl border border-success/20 bg-success/10 px-4 py-3 flex items-center justify-between"
              >
                <span className="text-success text-sm font-medium">{success}</span>
                <button onClick={clearMessages} className="text-success/60 hover:text-success ml-3 h-6 w-6 flex items-center justify-center">
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </motion.div>
            )}
          </AnimatePresence>

          {/* Stats Row */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
            <StatCard
              icon={
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-1.053M18 1.5a3 3 0 11-6 0 3 3 0 016 0zm-9 8.25a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
              }
              label="Total Users"
              value={users.length}
            />
            <StatCard
              icon={
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
                </svg>
              }
              label="Active Today"
              value="--"
            />
            <StatCard
              icon={
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
                </svg>
              }
              label="Total Entries"
              value={totals.totalEntries}
            />
            <StatCard
              icon={
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.455 2.456L21.75 6l-1.036.259a3.375 3.375 0 00-2.455 2.456z" />
                </svg>
              }
              label="AI Credits"
              value="--"
            />
          </div>

          {/* Tabs */}
          <div className="flex items-center gap-1 mb-6 border-b border-border-subtle">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`relative px-4 h-11 text-sm font-medium transition-colors ${
                  activeTab === tab.id
                    ? 'text-primary'
                    : 'text-white/40 hover:text-white/70'
                }`}
              >
                {tab.label}
                {activeTab === tab.id && (
                  <motion.div
                    layoutId="admin-tab-indicator"
                    className="absolute bottom-0 left-0 right-0 h-0.5 bg-primary rounded-full"
                  />
                )}
              </button>
            ))}
          </div>

          {/* Tab Content */}
          {activeTab === 'users' && (
            <div className="space-y-6">
              {/* User Selection */}
              <GlassCard className="p-5">
                <div className="flex flex-col sm:flex-row sm:items-end gap-4">
                  <div className="flex-1">
                    <label className="block text-label text-white/50 mb-2">Select User</label>
                    <select
                      value={selectedEmail}
                      onChange={e => setSelectedEmail(e.target.value)}
                      disabled={usersLoading}
                      className="w-full bg-surface-2 border border-border-subtle rounded-xl h-11 px-4 text-white outline-none focus:border-primary/50 focus:ring-1 focus:ring-primary/25 transition-colors appearance-none cursor-pointer"
                    >
                      {usersLoading ? (
                        <option>Loading users...</option>
                      ) : users.length === 0 ? (
                        <option>No users found</option>
                      ) : (
                        users.map(u => (
                          <option key={u.email} value={u.email}>
                            {u.name || 'Unnamed User'} -- {u.email}
                            {u.is_admin ? ' (Admin)' : ''}
                          </option>
                        ))
                      )}
                    </select>
                  </div>
                  <ActionButton
                    variant="ghost"
                    onClick={resetTodayForUser}
                    className="text-error hover:bg-error/10 border-error/20"
                    icon={
                      <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                      </svg>
                    }
                  >
                    Reset Today
                  </ActionButton>
                </div>
              </GlassCard>

              {/* User Info Card */}
              {selectedUser && (
                <GlassCard className="p-5">
                  <div className="flex items-center gap-4">
                    <div className="w-14 h-14 rounded-full bg-gradient-primary flex items-center justify-center shadow-glow-primary shrink-0">
                      <span className="text-white text-xl font-bold">
                        {selectedUser.name ? selectedUser.name.charAt(0).toUpperCase() : 'U'}
                      </span>
                    </div>
                    <div className="min-w-0">
                      <h3 className="text-white font-semibold text-lg">{selectedUser.name || 'Unnamed User'}</h3>
                      <p className="text-white/40 text-sm">{selectedUser.email}</p>
                      <div className="flex items-center gap-3 mt-1">
                        <Badge variant={selectedUser.is_admin ? 'intensity' : 'status'}>
                          {selectedUser.is_admin ? 'Admin' : 'User'}
                        </Badge>
                        <span className="text-white/30 text-xs">
                          Joined {selectedUser.created_at ? new Date(selectedUser.created_at).toLocaleDateString() : '--'}
                        </span>
                      </div>
                    </div>
                  </div>
                </GlassCard>
              )}

              {/* User Stats */}
              <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
                <GlassCard className="p-4 text-center">
                  <p className="text-white/40 text-xs mb-1">Total Entries</p>
                  <p className="text-stat text-white">{totals.totalEntries}</p>
                </GlassCard>
                <GlassCard className="p-4 text-center">
                  <p className="text-white/40 text-xs mb-1">Workouts</p>
                  <p className="text-stat text-white">{totals.workouts}</p>
                </GlassCard>
                <GlassCard className="p-4 text-center">
                  <p className="text-white/40 text-xs mb-1">Burned</p>
                  <p className="text-stat text-warning">{totals.burned} kcal</p>
                </GlassCard>
                <GlassCard className="p-4 text-center">
                  <p className="text-white/40 text-xs mb-1">Consumed</p>
                  <p className="text-stat text-success">{totals.consumed} kcal</p>
                </GlassCard>
                <GlassCard className="p-4 text-center">
                  <p className="text-white/40 text-xs mb-1">Sleep</p>
                  <p className="text-stat text-primary">{totals.sleepHrs}h</p>
                </GlassCard>
                <GlassCard className="p-4 text-center">
                  <p className="text-white/40 text-xs mb-1">Net Calories</p>
                  <p className={`text-stat ${totals.consumed - totals.burned >= 0 ? 'text-success' : 'text-error'}`}>
                    {totals.consumed - totals.burned >= 0 ? '+' : ''}{totals.consumed - totals.burned}
                  </p>
                </GlassCard>
              </div>

              {/* Users Table */}
              <GlassCard className="p-5">
                <h3 className="text-white font-semibold mb-4">All Users</h3>
                {usersLoading ? (
                  <LoadingSkeleton variant="table" count={5} />
                ) : (
                  <DataTable
                    columns={userTableColumns}
                    data={users}
                    onRowClick={(row) => setSelectedEmail(row.email)}
                    emptyState={
                      <EmptyState
                        title="No users found"
                        message="Users will appear here once they register."
                      />
                    }
                  />
                )}
              </GlassCard>

              {/* Entries Sections */}
              <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                {/* Activities */}
                <GlassCard className="p-5">
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="text-white font-semibold text-sm">Activities</h3>
                    <Badge variant="status">{entries.activities.length}</Badge>
                  </div>

                  {entriesLoading ? (
                    <LoadingSkeleton count={3} />
                  ) : entries.activities.length === 0 ? (
                    <EmptyState title="No activities" message="No activities logged" />
                  ) : (
                    <div className="space-y-2 max-h-80 overflow-y-auto">
                      {entries.activities.map(activity => (
                        <div key={`a-${activity.id}`} className="flex items-center gap-3 p-3 rounded-xl bg-surface-2/50">
                          <div className="w-8 h-8 rounded-lg bg-warning/10 flex items-center justify-center shrink-0">
                            <span className="text-sm">💪</span>
                          </div>
                          <div className="flex-1 min-w-0">
                            <p className="text-white text-sm font-medium truncate">{activity.activity}</p>
                            <p className="text-white/40 text-xs">
                              {activity.duration_min} min / {activity.calories} kcal
                            </p>
                          </div>
                          <span className="text-white/20 text-xs shrink-0">
                            {new Date(activity.entry_date).toLocaleDateString()}
                          </span>
                        </div>
                      ))}
                    </div>
                  )}
                </GlassCard>

                {/* Food */}
                <GlassCard className="p-5">
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="text-white font-semibold text-sm">Food</h3>
                    <Badge variant="status">{entries.food.length}</Badge>
                  </div>

                  {entriesLoading ? (
                    <LoadingSkeleton count={3} />
                  ) : entries.food.length === 0 ? (
                    <EmptyState title="No food entries" message="No food logged" />
                  ) : (
                    <div className="space-y-2 max-h-80 overflow-y-auto">
                      {entries.food.map(food => (
                        <div key={`f-${food.id}`} className="flex items-center gap-3 p-3 rounded-xl bg-surface-2/50">
                          <div className="w-8 h-8 rounded-lg bg-success/10 flex items-center justify-center shrink-0">
                            <span className="text-sm">🍽️</span>
                          </div>
                          <div className="flex-1 min-w-0">
                            <p className="text-white text-sm font-medium truncate">{food.name}</p>
                            <p className="text-white/40 text-xs">
                              {food.calories} kcal / P: {food.protein}g / S: {food.sugar}g
                            </p>
                          </div>
                          <span className="text-white/20 text-xs shrink-0">
                            {new Date(food.entry_date).toLocaleDateString()}
                          </span>
                        </div>
                      ))}
                    </div>
                  )}
                </GlassCard>

                {/* Sleep */}
                <GlassCard className="p-5">
                  <div className="flex items-center justify-between mb-4">
                    <h3 className="text-white font-semibold text-sm">Sleep</h3>
                    <Badge variant="status">{entries.sleep.length}</Badge>
                  </div>

                  {entriesLoading ? (
                    <LoadingSkeleton count={3} />
                  ) : entries.sleep.length === 0 ? (
                    <EmptyState title="No sleep data" message="No sleep logged" />
                  ) : (
                    <div className="space-y-2 max-h-80 overflow-y-auto">
                      {entries.sleep.map(sleep => (
                        <div key={`s-${sleep.id}`} className="flex items-center gap-3 p-3 rounded-xl bg-surface-2/50">
                          <div className="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center shrink-0">
                            <span className="text-sm">😴</span>
                          </div>
                          <div className="flex-1 min-w-0">
                            <p className="text-white text-sm font-medium truncate">{sleep.hours} hours</p>
                            <p className="text-white/40 text-xs">{sleep.quality}</p>
                          </div>
                          <span className="text-white/20 text-xs shrink-0">
                            {new Date(sleep.entry_date).toLocaleDateString()}
                          </span>
                        </div>
                      ))}
                    </div>
                  )}
                </GlassCard>
              </div>
            </div>
          )}

          {activeTab === 'ai-errors' && (
            <GlassCard className="p-8">
              <EmptyState
                icon={
                  <svg className="w-10 h-10 text-white/20" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
                  </svg>
                }
                title="AI Error Management"
                message="View and manage AI errors from the dedicated error manager."
                action={{
                  label: 'Open AI Error Manager',
                  onClick: () => navigate('/dashboard/admin/ai-errors')
                }}
              />
              <div className="flex flex-wrap gap-2 mt-6 justify-center">
                <Badge variant="severity">Critical</Badge>
                <Badge variant="severity">Warning</Badge>
                <Badge variant="severity">Info</Badge>
              </div>
            </GlassCard>
          )}

          {activeTab === 'system' && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <h3 className="text-white font-semibold">System Status</h3>
                <ActionButton variant="ghost" onClick={fetchApiHealth}>
                  Refresh
                </ActionButton>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                <GlassCard className="p-5">
                  <p className="text-label text-white/40 mb-2">API Health</p>
                  <div className="flex items-center gap-2">
                    <div className={`w-2.5 h-2.5 rounded-full ${apiHealth?.status === 'healthy' ? 'bg-success animate-pulse' : 'bg-error'}`} />
                    <span className={`font-semibold text-sm ${apiHealth?.status === 'healthy' ? 'text-success' : 'text-error'}`}>
                      {apiHealth ? apiHealth.status?.toUpperCase() || 'UNKNOWN' : 'LOADING'}
                    </span>
                  </div>
                </GlassCard>

                <GlassCard className="p-5">
                  <p className="text-label text-white/40 mb-2">Database</p>
                  <div className="flex items-center gap-2">
                    <div className={`w-2.5 h-2.5 rounded-full ${apiHealth?.database?.status === 'connected' ? 'bg-success animate-pulse' : 'bg-error'}`} />
                    <span className={`font-semibold text-sm ${apiHealth?.database?.status === 'connected' ? 'text-success' : 'text-error'}`}>
                      {apiHealth?.database ? apiHealth.database.status?.toUpperCase() || 'UNKNOWN' : 'LOADING'}
                    </span>
                  </div>
                </GlassCard>

                <GlassCard className="p-5">
                  <p className="text-label text-white/40 mb-2">Uptime</p>
                  <span className="text-white font-semibold text-sm">
                    {apiHealth?.uptime
                      ? `${Math.floor(apiHealth.uptime / 3600)}h ${Math.floor((apiHealth.uptime % 3600) / 60)}m`
                      : 'N/A'
                    }
                  </span>
                </GlassCard>

                <GlassCard className="p-5">
                  <p className="text-label text-white/40 mb-2">Memory</p>
                  <span className="text-white font-semibold text-sm">
                    {apiHealth?.memory ? `${apiHealth.memory.used}` : 'N/A'}
                  </span>
                </GlassCard>
              </div>
            </div>
          )}
        </div>
      </div>
    </PageTransition>
  );
}
