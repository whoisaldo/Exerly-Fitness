import React, { useState, useEffect } from 'react';
import './AdminStatusChecker.css';
import API_CONFIG from '../config';

export default function AdminStatusChecker() {
  const [apiHealth, setApiHealth] = useState(null);
  const [loading, setLoading] = useState(true);
  const [systemAnnouncement, setSystemAnnouncement] = useState({
    title: '',
    message: '',
    type: 'info',
    isActive: true
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
        timestamp: new Date().toISOString()
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
        createdBy: 'Admin'
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
        isActive: true
      });
      
      setTimeout(() => setSubmitStatus(''), 3000);
    } catch (error) {
      setSubmitStatus('error');
      setTimeout(() => setSubmitStatus(''), 3000);
    }
  };

  const deleteAnnouncement = (id) => {
    const updatedAnnouncements = announcements.filter(ann => ann.id !== id);
    setAnnouncements(updatedAnnouncements);
    localStorage.setItem('systemAnnouncements', JSON.stringify(updatedAnnouncements));
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

  const getAnnouncementTypeColor = (type) => {
    switch (type) {
      case 'info':
        return '#3498db';
      case 'warning':
        return '#f39c12';
      case 'error':
        return '#e74c3c';
      case 'success':
        return '#27ae60';
      default:
        return '#95a5a6';
    }
  };

  return (
    <div className="admin-status-checker">
      <div className="admin-header">
        <h1>🔧 Advanced Status Checker</h1>
        <p>Admin-only system monitoring and announcements</p>
      </div>

      {/* Detailed API Health */}
      <div className="admin-section">
        <h2>📊 Detailed API Health Metrics</h2>
        <div className="detailed-health-card">
          {loading ? (
            <div className="loading">Loading detailed metrics...</div>
          ) : (
            <div className="health-grid">
              <div className="health-metric">
                <div className="metric-header">
                  <span className="status-icon">{getStatusIcon(apiHealth?.status)}</span>
                  <span 
                    className="status-text"
                    style={{ color: getStatusColor(apiHealth?.status) }}
                  >
                    {apiHealth?.status?.toUpperCase() || 'UNKNOWN'}
                  </span>
                </div>
                <div className="metric-value">
                  Last Check: {apiHealth ? new Date(apiHealth.timestamp).toLocaleString() : 'N/A'}
                </div>
              </div>

              <div className="health-metric">
                <div className="metric-label">Uptime</div>
                <div className="metric-value">
                  {apiHealth?.uptime ? 
                    `${Math.floor(apiHealth.uptime / 3600)}h ${Math.floor((apiHealth.uptime % 3600) / 60)}m` : 
                    'N/A'
                  }
                </div>
              </div>

              <div className="health-metric">
                <div className="metric-label">Database</div>
                <div className="metric-value">
                  <span 
                    style={{ 
                      color: apiHealth?.database?.status === 'connected' ? '#27ae60' : '#e74c3c',
                      fontWeight: 'bold'
                    }}
                  >
                    {apiHealth?.database?.status?.toUpperCase() || 'UNKNOWN'}
                  </span>
                  {apiHealth?.database?.name && (
                    <span className="db-name">({apiHealth.database.name})</span>
                  )}
                </div>
              </div>

              <div className="health-metric">
                <div className="metric-label">Memory Usage</div>
                <div className="metric-value">
                  {apiHealth?.memory ? 
                    `${apiHealth.memory.used} / ${apiHealth.memory.total}` : 
                    'N/A'
                  }
                </div>
              </div>

              <div className="health-metric">
                <div className="metric-label">Version</div>
                <div className="metric-value">
                  {apiHealth?.version || 'N/A'}
                </div>
              </div>

              <div className="health-metric">
                <div className="metric-label">Connection State</div>
                <div className="metric-value">
                  {apiHealth?.database?.readyState === 1 ? 'Connected' : 'Disconnected'}
                </div>
              </div>
            </div>
          )}
          
          <div className="health-actions">
            <button className="action-btn primary" onClick={fetchDetailedHealth}>
              🔄 Refresh Metrics
            </button>
            <button className="action-btn secondary" onClick={() => window.open(`${API_CONFIG.BASE_URL}/api/health`, '_blank')}>
              🔗 View Raw Data
            </button>
          </div>
        </div>
      </div>

      {/* System Announcements */}
      <div className="admin-section">
        <h2>📢 System Announcements</h2>
        
        {/* Create New Announcement */}
        <div className="announcement-form-card">
          <h3>Create New Announcement</h3>
          <form className="announcement-form" onSubmit={handleAnnouncementSubmit}>
            <div className="form-row">
              <div className="form-group">
                <label htmlFor="announcement-title">Title *</label>
                <input
                  type="text"
                  id="announcement-title"
                  value={systemAnnouncement.title}
                  onChange={(e) => setSystemAnnouncement({...systemAnnouncement, title: e.target.value})}
                  placeholder="System maintenance scheduled..."
                  required
                />
              </div>

              <div className="form-group">
                <label htmlFor="announcement-type">Type</label>
                <select
                  id="announcement-type"
                  value={systemAnnouncement.type}
                  onChange={(e) => setSystemAnnouncement({...systemAnnouncement, type: e.target.value})}
                >
                  <option value="info">ℹ️ Info</option>
                  <option value="warning">⚠️ Warning</option>
                  <option value="error">❌ Error</option>
                  <option value="success">✅ Success</option>
                </select>
              </div>
            </div>

            <div className="form-group">
              <label htmlFor="announcement-message">Message *</label>
              <textarea
                id="announcement-message"
                value={systemAnnouncement.message}
                onChange={(e) => setSystemAnnouncement({...systemAnnouncement, message: e.target.value})}
                placeholder="System is experiencing issues and will be fixed later..."
                rows="4"
                required
              />
            </div>

            <div className="form-group checkbox-group">
              <label className="checkbox-label">
                <input
                  type="checkbox"
                  checked={systemAnnouncement.isActive}
                  onChange={(e) => setSystemAnnouncement({...systemAnnouncement, isActive: e.target.checked})}
                />
                <span className="checkmark"></span>
                Active (visible to users)
              </label>
            </div>

            <button 
              type="submit" 
              className="submit-announcement-btn"
              disabled={submitStatus === 'submitting'}
            >
              {submitStatus === 'submitting' ? 'Publishing...' : '📢 Publish Announcement'}
            </button>

            {submitStatus === 'success' && (
              <div className="submit-message success">
                ✅ Announcement published successfully!
              </div>
            )}

            {submitStatus === 'error' && (
              <div className="submit-message error">
                ❌ Failed to publish announcement. Please try again.
              </div>
            )}
          </form>
        </div>

        {/* Existing Announcements */}
        <div className="announcements-list">
          <h3>Recent Announcements</h3>
          {announcements.length === 0 ? (
            <div className="no-announcements">
              <p>No announcements yet. Create one above!</p>
            </div>
          ) : (
            <div className="announcements-grid">
              {announcements.map((announcement) => (
                <div 
                  key={announcement.id} 
                  className="announcement-card"
                  style={{ borderLeftColor: getAnnouncementTypeColor(announcement.type) }}
                >
                  <div className="announcement-header">
                    <div className="announcement-type">
                      <span 
                        className="type-indicator"
                        style={{ backgroundColor: getAnnouncementTypeColor(announcement.type) }}
                      >
                        {announcement.type.toUpperCase()}
                      </span>
                      <span className="announcement-status">
                        {announcement.isActive ? '🟢 Active' : '🔴 Inactive'}
                      </span>
                    </div>
                    <button 
                      className="delete-announcement"
                      onClick={() => deleteAnnouncement(announcement.id)}
                      title="Delete announcement"
                    >
                      🗑️
                    </button>
                  </div>
                  
                  <h4 className="announcement-title">{announcement.title}</h4>
                  <p className="announcement-message">{announcement.message}</p>
                  
                  <div className="announcement-meta">
                    <span>Created: {new Date(announcement.createdAt).toLocaleString()}</span>
                    <span>By: {announcement.createdBy}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Admin Tools */}
      <div className="admin-section">
        <h2>🛠️ Admin Tools</h2>
        <div className="admin-tools">
          <button className="admin-tool-btn" onClick={() => window.open('/#/status-check', '_blank')}>
            👁️ View Public Status Page
          </button>
          <button className="admin-tool-btn" onClick={() => window.open(`${API_CONFIG.BASE_URL}/api/health`, '_blank')}>
            🔍 API Health JSON
          </button>
          <button className="admin-tool-btn" onClick={() => {
            localStorage.removeItem('systemAnnouncements');
            setAnnouncements([]);
          }}>
            🧹 Clear All Announcements
          </button>
        </div>
      </div>
    </div>
  );
}
