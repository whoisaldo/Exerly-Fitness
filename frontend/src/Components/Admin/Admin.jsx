// frontend/src/Components/Admin/Admin.jsx
import React, { useEffect, useState, useMemo, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import '../Dashboard/Dashboard.css';
import './Admin.css';
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

  const token = localStorage.getItem('token') || '';
  const me = useMemo(() => decodeJWT(token) || {}, [token]);

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

  return (
    <div className="admin-page">
      {/* Enhanced Header */}
      <header className="admin-header">
        <div className="header-left">
          <div className="admin-badge">👑 Admin Console</div>
          <h1 className="admin-title">User Management</h1>
          <p className="admin-subtitle">
            Monitor user activity, view logs, and manage data
          </p>
        </div>
        
        <div className="header-right">
          <button 
            className="action-btn back-btn"
            onClick={() => navigate('/dashboard')}
            title="Back to Dashboard"
          >
            ← Back
          </button>
        </div>
      </header>

      {/* Messages */}
      {error && (
        <div className="message-banner error">
          <span className="message-text">{error}</span>
          <button className="message-close" onClick={clearMessages}>×</button>
        </div>
      )}
      
      {success && (
        <div className="message-banner success">
          <span className="message-text">{success}</span>
          <button className="message-close" onClick={clearMessages}>×</button>
        </div>
      )}

      {/* User Selection Toolbar */}
      <section className="admin-toolbar">
        <div className="toolbar-left">
          <label className="toolbar-label">Select User</label>
          <select 
            className="user-select"
            value={selectedEmail}
            onChange={e => setSelectedEmail(e.target.value)}
            disabled={usersLoading}
          >
            {usersLoading ? (
              <option>Loading users...</option>
            ) : users.length === 0 ? (
              <option>No users found</option>
            ) : (
              users.map(u => (
                <option key={u.email} value={u.email}>
                  {u.name || 'Unnamed User'} • {u.email}
                  {u.is_admin ? ' (Admin)' : ''}
                </option>
              ))
            )}
          </select>
        </div>
        
        <div className="toolbar-right">
          <button 
            className="action-btn reset-btn"
            onClick={resetTodayForUser}
            disabled={!selectedEmail || entriesLoading}
            title="Reset today's data for selected user"
          >
            🗑️ Reset Today
          </button>
        </div>
      </section>

      {/* User Info */}
      {selectedUser && (
        <section className="user-info">
          <div className="user-card">
            <div className="user-avatar">
              {selectedUser.name ? selectedUser.name.charAt(0).toUpperCase() : 'U'}
            </div>
            <div className="user-details">
              <h3 className="user-name">{selectedUser.name || 'Unnamed User'}</h3>
              <p className="user-email">{selectedUser.email}</p>
              <div className="user-meta">
                <span className="user-role">
                  {selectedUser.is_admin ? '👑 Admin' : '👤 User'}
                </span>
                <span className="user-joined">
                  Joined {new Date(selectedUser.created_at).toLocaleDateString()}
                </span>
              </div>
            </div>
          </div>
        </section>
      )}

      {/* Statistics Overview */}
      <section className="stats-section">
        <h2 className="section-title">User Statistics</h2>
        <div className="stats-grid">
          <div className="stats-card total-entries">
            <div className="card-icon">📊</div>
            <div className="card-content">
              <h3 className="card-label">Total Entries</h3>
              <div className="card-value">{totals.totalEntries}</div>
            </div>
          </div>
          
          <div className="stats-card workouts">
            <div className="card-icon">💪</div>
            <div className="card-content">
              <h3 className="card-label">Workouts</h3>
              <div className="card-value">{totals.workouts}</div>
            </div>
          </div>
          
          <div className="stats-card calories-burned">
            <div className="card-icon">🔥</div>
            <div className="card-content">
              <h3 className="card-label">Calories Burned</h3>
              <div className="card-value">{totals.burned} kcal</div>
            </div>
          </div>
          
          <div className="stats-card calories-consumed">
            <div className="card-icon">🍽️</div>
            <div className="card-content">
              <h3 className="card-label">Calories Consumed</h3>
              <div className="card-value">{totals.consumed} kcal</div>
            </div>
          </div>
          
          <div className="stats-card sleep">
            <div className="card-icon">😴</div>
            <div className="card-content">
              <h3 className="card-label">Sleep Hours</h3>
              <div className="card-value">{totals.sleepHrs}h</div>
            </div>
          </div>
          
          <div className="stats-card net-calories">
            <div className="card-icon">⚖️</div>
            <div className="card-content">
              <h3 className="card-label">Net Calories</h3>
              <div className={`card-value ${totals.consumed - totals.burned >= 0 ? 'positive' : 'negative'}`}>
                {totals.consumed - totals.burned >= 0 ? '+' : ''}{totals.consumed - totals.burned} kcal
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Detailed Entries */}
      <section className="entries-section">
        <h2 className="section-title">Detailed Entries</h2>
        
        <div className="entries-tabs">
          <div className="tab-content">
            {/* Activities Tab */}
            <div className="tab-panel">
              <div className="panel-header">
                <h3 className="panel-title">💪 Activities</h3>
                <span className="entry-count">{entries.activities.length} entries</span>
              </div>
              
              {entriesLoading ? (
                <div className="loading-state">
                  <div className="spinner"></div>
                  <p>Loading activities...</p>
                </div>
              ) : entries.activities.length === 0 ? (
                <div className="empty-state">
                  <p>No activities logged</p>
                </div>
              ) : (
                <div className="entries-list">
                  {entries.activities.map(activity => (
                    <div key={`a-${activity.id}`} className="entry-item activity">
                      <div className="entry-icon">💪</div>
                      <div className="entry-content">
                        <div className="entry-name">{activity.activity}</div>
                        <div className="entry-details">
                          <span className="entry-duration">{activity.duration_min} min</span>
                          <span className="entry-calories">{activity.calories} kcal</span>
                        </div>
                      </div>
                      <div className="entry-date">
                        {new Date(activity.entry_date).toLocaleDateString()}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Food Tab */}
            <div className="tab-panel">
              <div className="panel-header">
                <h3 className="panel-title">🍽️ Food</h3>
                <span className="entry-count">{entries.food.length} entries</span>
              </div>
              
              {entriesLoading ? (
                <div className="loading-state">
                  <div className="spinner"></div>
                  <p>Loading food entries...</p>
                </div>
              ) : entries.food.length === 0 ? (
                <div className="empty-state">
                  <p>No food logged</p>
                </div>
              ) : (
                <div className="entries-list">
                  {entries.food.map(food => (
                    <div key={`f-${food.id}`} className="entry-item food">
                      <div className="entry-icon">🍽️</div>
                      <div className="entry-content">
                        <div className="entry-name">{food.name}</div>
                        <div className="entry-details">
                          <span className="entry-calories">{food.calories} kcal</span>
                          <span className="entry-macros">
                            P: {food.protein}g • S: {food.sugar}g
                          </span>
                        </div>
                      </div>
                      <div className="entry-date">
                        {new Date(food.entry_date).toLocaleDateString()}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Sleep Tab */}
            <div className="tab-panel">
              <div className="panel-header">
                <h3 className="panel-title">😴 Sleep</h3>
                <span className="entry-count">{entries.sleep.length} entries</span>
              </div>
              
              {entriesLoading ? (
                <div className="loading-state">
                  <div className="spinner"></div>
                  <p>Loading sleep data...</p>
                </div>
              ) : entries.sleep.length === 0 ? (
                <div className="empty-state">
                  <p>No sleep logged</p>
                </div>
              ) : (
                <div className="entries-list">
                  {entries.sleep.map(sleep => (
                    <div key={`s-${sleep.id}`} className="entry-item sleep">
                      <div className="entry-icon">😴</div>
                      <div className="entry-content">
                        <div className="entry-name">{sleep.hours} hours</div>
                        <div className="entry-details">
                          <span className="entry-quality">{sleep.quality}</span>
                        </div>
                      </div>
                      <div className="entry-date">
                        {new Date(sleep.entry_date).toLocaleDateString()}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}