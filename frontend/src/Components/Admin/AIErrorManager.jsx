import React, { useState, useEffect } from 'react';
import './AIErrorManager.css';

const AIErrorManager = () => {
  const [errors, setErrors] = useState([]);
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [selectedError, setSelectedError] = useState(null);
  const [filters, setFilters] = useState({
    status: '',
    severity: '',
    errorType: ''
  });
  const [pagination, setPagination] = useState({
    page: 1,
    limit: 20,
    total: 0,
    pages: 0
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
        ...filters
      });

      const response = await fetch(`/api/admin/ai-errors?${queryParams}`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });

      if (response.ok) {
        const data = await response.json();
        setErrors(data.errors);
        setPagination(prev => ({
          ...prev,
          ...data.pagination
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
      const response = await fetch('/api/admin/ai-errors/stats', {
        headers: { 'Authorization': `Bearer ${token}` }
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
      const response = await fetch(`/api/admin/ai-errors/${errorId}/status`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ status, adminNotes })
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
      const response = await fetch(`/api/admin/ai-errors/${errorId}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
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
    if (!window.confirm('Are you sure you want to clean up old errors? This action cannot be undone.')) return;

    try {
      const token = localStorage.getItem('token');
      const response = await fetch('/api/admin/ai-errors/cleanup', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ daysOld: 30 })
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

  const getSeverityColor = (severity) => {
    switch (severity) {
      case 'CRITICAL': return '#ef4444';
      case 'HIGH': return '#f97316';
      case 'MEDIUM': return '#eab308';
      case 'LOW': return '#22c55e';
      default: return '#6b7280';
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'OPEN': return '#ef4444';
      case 'INVESTIGATING': return '#f97316';
      case 'RESOLVED': return '#22c55e';
      case 'IGNORED': return '#6b7280';
      default: return '#6b7280';
    }
  };

  const formatDate = (dateString) => {
    return new Date(dateString).toLocaleString();
  };

  if (loading) {
    return (
      <div className="ai-error-manager">
        <div className="loading">Loading AI errors...</div>
      </div>
    );
  }

  return (
    <div className="ai-error-manager">
      <div className="error-manager-header">
        <h1>AI Error Management</h1>
        <div className="header-actions">
          <button onClick={cleanupOldErrors} className="cleanup-btn">
            Cleanup Old Errors
          </button>
          <button onClick={fetchErrors} className="refresh-btn">
            Refresh
          </button>
        </div>
      </div>

      {/* Stats Overview */}
      {stats && (
        <div className="stats-overview">
          <div className="stat-card">
            <div className="stat-number">{stats.totalErrors}</div>
            <div className="stat-label">Total Errors</div>
          </div>
          <div className="stat-card">
            <div className="stat-number">{stats.openErrors}</div>
            <div className="stat-label">Open Errors</div>
          </div>
          <div className="stat-card">
            <div className="stat-number">{stats.criticalErrors}</div>
            <div className="stat-label">Critical Errors</div>
          </div>
        </div>
      )}

      {/* Filters */}
      <div className="filters-section">
        <div className="filter-group">
          <label>Status:</label>
          <select 
            value={filters.status} 
            onChange={(e) => setFilters(prev => ({ ...prev, status: e.target.value }))}
          >
            <option value="">All</option>
            <option value="OPEN">Open</option>
            <option value="INVESTIGATING">Investigating</option>
            <option value="RESOLVED">Resolved</option>
            <option value="IGNORED">Ignored</option>
          </select>
        </div>
        <div className="filter-group">
          <label>Severity:</label>
          <select 
            value={filters.severity} 
            onChange={(e) => setFilters(prev => ({ ...prev, severity: e.target.value }))}
          >
            <option value="">All</option>
            <option value="CRITICAL">Critical</option>
            <option value="HIGH">High</option>
            <option value="MEDIUM">Medium</option>
            <option value="LOW">Low</option>
          </select>
        </div>
        <div className="filter-group">
          <label>Type:</label>
          <select 
            value={filters.errorType} 
            onChange={(e) => setFilters(prev => ({ ...prev, errorType: e.target.value }))}
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

      {/* Errors List */}
      <div className="errors-list">
        {errors.length === 0 ? (
          <div className="no-errors">No errors found</div>
        ) : (
          errors.map((error) => (
            <div key={error._id} className="error-card" onClick={() => setSelectedError(error)}>
              <div className="error-header">
                <div className="error-info">
                  <span className="error-type">{error.errorType}</span>
                  <span className="error-code">{error.errorCode}</span>
                </div>
                <div className="error-badges">
                  <span 
                    className="severity-badge" 
                    style={{ backgroundColor: getSeverityColor(error.severity) }}
                  >
                    {error.severity}
                  </span>
                  <span 
                    className="status-badge" 
                    style={{ backgroundColor: getStatusColor(error.status) }}
                  >
                    {error.status}
                  </span>
                </div>
              </div>
              <div className="error-message">{error.errorMessage}</div>
              <div className="error-meta">
                <span className="error-user">{error.email}</span>
                <span className="error-date">{formatDate(error.created_at)}</span>
              </div>
            </div>
          ))
        )}
      </div>

      {/* Pagination */}
      {pagination.pages > 1 && (
        <div className="pagination">
          <button 
            onClick={() => setPagination(prev => ({ ...prev, page: prev.page - 1 }))}
            disabled={pagination.page === 1}
          >
            Previous
          </button>
          <span>Page {pagination.page} of {pagination.pages}</span>
          <button 
            onClick={() => setPagination(prev => ({ ...prev, page: prev.page + 1 }))}
            disabled={pagination.page === pagination.pages}
          >
            Next
          </button>
        </div>
      )}

      {/* Error Detail Modal */}
      {selectedError && (
        <div className="error-modal-overlay" onClick={() => setSelectedError(null)}>
          <div className="error-modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h2>Error Details</h2>
              <button onClick={() => setSelectedError(null)} className="close-btn">×</button>
            </div>
            <div className="modal-content">
              <div className="error-details">
                <div className="detail-row">
                  <label>Error Type:</label>
                  <span>{selectedError.errorType}</span>
                </div>
                <div className="detail-row">
                  <label>Error Code:</label>
                  <span>{selectedError.errorCode}</span>
                </div>
                <div className="detail-row">
                  <label>Severity:</label>
                  <span style={{ color: getSeverityColor(selectedError.severity) }}>
                    {selectedError.severity}
                  </span>
                </div>
                <div className="detail-row">
                  <label>Status:</label>
                  <span style={{ color: getStatusColor(selectedError.status) }}>
                    {selectedError.status}
                  </span>
                </div>
                <div className="detail-row">
                  <label>User:</label>
                  <span>{selectedError.email}</span>
                </div>
                <div className="detail-row">
                  <label>Session ID:</label>
                  <span>{selectedError.sessionId}</span>
                </div>
                <div className="detail-row">
                  <label>Created:</label>
                  <span>{formatDate(selectedError.created_at)}</span>
                </div>
                <div className="detail-row">
                  <label>Message:</label>
                  <span>{selectedError.errorMessage}</span>
                </div>
                {selectedError.stackTrace && (
                  <div className="detail-row">
                    <label>Stack Trace:</label>
                    <pre className="stack-trace">{selectedError.stackTrace}</pre>
                  </div>
                )}
                {selectedError.adminNotes && (
                  <div className="detail-row">
                    <label>Admin Notes:</label>
                    <span>{selectedError.adminNotes}</span>
                  </div>
                )}
              </div>
              <div className="modal-actions">
                <select 
                  onChange={(e) => updateErrorStatus(selectedError._id, e.target.value)}
                  value={selectedError.status}
                >
                  <option value="OPEN">Open</option>
                  <option value="INVESTIGATING">Investigating</option>
                  <option value="RESOLVED">Resolved</option>
                  <option value="IGNORED">Ignored</option>
                </select>
                <button 
                  onClick={() => deleteError(selectedError._id)}
                  className="delete-btn"
                >
                  Delete
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default AIErrorManager;
