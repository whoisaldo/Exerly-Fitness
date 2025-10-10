import React, { useState, useEffect } from 'react';
import './StatusCheck.css';
import API_CONFIG from '../config';

export default function StatusCheck() {
  const [apiHealth, setApiHealth] = useState(null);
  const [loading, setLoading] = useState(true);
  const [bugReport, setBugReport] = useState({
    title: '',
    description: '',
    email: '',
    severity: 'medium'
  });
  const [submitStatus, setSubmitStatus] = useState('');

  // Fetch API health status
  const fetchApiHealth = async () => {
    try {
      const response = await fetch(`${API_CONFIG.BASE_URL}/api/health`);
      const data = await response.json();
      setApiHealth(data);
    } catch (error) {
      setApiHealth({
        status: 'unhealthy',
        error: 'Failed to connect to API',
        timestamp: new Date().toISOString()
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
        severity: 'medium'
      });
      
      setTimeout(() => setSubmitStatus(''), 3000);
    } catch (error) {
      setSubmitStatus('error');
      setTimeout(() => setSubmitStatus(''), 3000);
    }
  };

  const getStatusIcon = (status) => {
    switch (status) {
      case 'healthy':
        return '🟢';
      case 'unhealthy':
        return '🔴';
      default:
        return '🟡';
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'healthy':
        return '#27ae60';
      case 'unhealthy':
        return '#e74c3c';
      default:
        return '#f39c12';
    }
  };

  return (
    <div className="status-check">
      <div className="status-header">
        <h1>System Status</h1>
        <p>Monitor API health and report issues</p>
      </div>

      {/* API Health Status */}
      <div className="status-section">
        <h2>API Health Status</h2>
        <div className="health-card">
          {loading ? (
            <div className="loading">Checking API status...</div>
          ) : (
            <div className="health-content">
              <div className="health-header">
                <span className="status-icon">{getStatusIcon(apiHealth?.status)}</span>
                <span 
                  className="status-text"
                  style={{ color: getStatusColor(apiHealth?.status) }}
                >
                  {apiHealth?.status?.toUpperCase() || 'UNKNOWN'}
                </span>
                <button className="refresh-btn" onClick={fetchApiHealth}>
                  🔄 Refresh
                </button>
              </div>
              
              {apiHealth && (
                <div className="health-details">
                  <div className="health-item">
                    <strong>Last Check:</strong> {new Date(apiHealth.timestamp).toLocaleString()}
                  </div>
                  
                  {apiHealth.uptime && (
                    <div className="health-item">
                      <strong>Uptime:</strong> {Math.floor(apiHealth.uptime / 3600)}h {Math.floor((apiHealth.uptime % 3600) / 60)}m
                    </div>
                  )}
                  
                  {apiHealth.database && (
                    <div className="health-item">
                      <strong>Database:</strong> 
                      <span 
                        className="db-status"
                        style={{ color: apiHealth.database.status === 'connected' ? '#27ae60' : '#e74c3c' }}
                      >
                        {apiHealth.database.status?.toUpperCase()}
                      </span>
                    </div>
                  )}
                  
                  {apiHealth.memory && (
                    <div className="health-item">
                      <strong>Memory Usage:</strong> {apiHealth.memory.used} / {apiHealth.memory.total}
                    </div>
                  )}
                  
                  {apiHealth.error && (
                    <div className="health-item error">
                      <strong>Error:</strong> {apiHealth.error}
                    </div>
                  )}
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Bug Report Form */}
      <div className="status-section">
        <h2>Report a Bug</h2>
        <form className="bug-report-form" onSubmit={handleBugReportSubmit}>
          <div className="form-group">
            <label htmlFor="title">Title *</label>
            <input
              type="text"
              id="title"
              value={bugReport.title}
              onChange={(e) => setBugReport({...bugReport, title: e.target.value})}
              placeholder="Brief description of the issue"
              required
            />
          </div>

          <div className="form-group">
            <label htmlFor="severity">Severity</label>
            <select
              id="severity"
              value={bugReport.severity}
              onChange={(e) => setBugReport({...bugReport, severity: e.target.value})}
            >
              <option value="low">Low - Minor issue</option>
              <option value="medium">Medium - Moderate issue</option>
              <option value="high">High - Major issue</option>
              <option value="critical">Critical - System down</option>
            </select>
          </div>

          <div className="form-group">
            <label htmlFor="email">Email (optional)</label>
            <input
              type="email"
              id="email"
              value={bugReport.email}
              onChange={(e) => setBugReport({...bugReport, email: e.target.value})}
              placeholder="your.email@example.com"
            />
          </div>

          <div className="form-group">
            <label htmlFor="description">Description *</label>
            <textarea
              id="description"
              value={bugReport.description}
              onChange={(e) => setBugReport({...bugReport, description: e.target.value})}
              placeholder="Please describe the issue in detail. Include steps to reproduce if possible."
              rows="5"
              required
            />
          </div>

          <button 
            type="submit" 
            className="submit-btn"
            disabled={submitStatus === 'submitting'}
          >
            {submitStatus === 'submitting' ? 'Submitting...' : 'Submit Bug Report'}
          </button>

          {submitStatus === 'success' && (
            <div className="submit-message success">
              ✅ Bug report submitted successfully!
            </div>
          )}

          {submitStatus === 'error' && (
            <div className="submit-message error">
              ❌ Failed to submit bug report. Please try again.
            </div>
          )}
        </form>
      </div>

      {/* Quick Links */}
      <div className="status-section">
        <h2>Quick Links</h2>
        <div className="quick-links">
          <a href="/#/maintenance-history" className="quick-link">
            📋 Maintenance History
          </a>
          <a href="/#/credits" className="quick-link">
            ℹ️ About & Credits
          </a>
          <a href="/#/" className="quick-link">
            🏠 Back to App
          </a>
        </div>
      </div>
    </div>
  );
}
