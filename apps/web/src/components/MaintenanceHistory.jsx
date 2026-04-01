import React from 'react';
import './MaintenanceHistory.css';

export default function MaintenanceHistory() {
  const maintenanceHistory = [
    {
      id: 1,
      date: 'October 18, 2024',
      duration: 'Ongoing',
      reason: 'Frontend Updates',
      description: 'Website may not be at full functionality right now due to ongoing frontend improvements and optimizations.',
      status: 'in-progress'
    },
    {
      id: 2,
      date: 'October 10, 2025',
      duration: '2 hours',
      reason: 'Database Migration',
      description: 'Migrated from PostgreSQL/SQLite to MongoDB Atlas for improved performance and scalability.',
      status: 'completed'
    },
    {
      id: 3,
      date: 'October 10, 2025',
      duration: '30 minutes',
      reason: 'System Maintenance',
      description: 'Routed database to different cloud service for improved performance and reliability.',
      status: 'completed'
    }
  ];

  const getStatusIcon = (status) => {
    switch (status) {
      case 'completed':
        return '✅';
      case 'scheduled':
        return '📅';
      case 'in-progress':
        return '🔄';
      default:
        return '📋';
    }
  };

  const getStatusClass = (status) => {
    switch (status) {
      case 'completed':
        return 'status-completed';
      case 'scheduled':
        return 'status-scheduled';
      case 'in-progress':
        return 'status-in-progress';
      default:
        return 'status-default';
    }
  };

  return (
    <div className="maintenance-history">
      <div className="maintenance-header">
        <h2>Maintenance History</h2>
        <p>Track of all scheduled and completed maintenance activities</p>
      </div>
      
      <div className="maintenance-timeline">
        {maintenanceHistory.map((entry, index) => (
          <div key={entry.id} className="maintenance-entry">
            <div className="timeline-marker">
              <span className="timeline-icon">{getStatusIcon(entry.status)}</span>
              {index < maintenanceHistory.length - 1 && <div className="timeline-line"></div>}
            </div>
            
            <div className="maintenance-content">
              <div className="maintenance-header-info">
                <h3>{entry.reason}</h3>
                <div className="maintenance-meta">
                  <span className="maintenance-date">{entry.date}</span>
                  <span className="maintenance-duration">{entry.duration}</span>
                  <span className={`maintenance-status ${getStatusClass(entry.status)}`}>
                    {entry.status.replace('-', ' ')}
                  </span>
                </div>
              </div>
              
              <div className="maintenance-description">
                <p>{entry.description}</p>
              </div>
            </div>
          </div>
        ))}
      </div>
      
      <div className="maintenance-footer">
        <p>
          <strong>System Status:</strong> All systems operational
        </p>
        <p className="last-updated">
          Last updated: {new Date().toLocaleDateString('en-US', { 
            year: 'numeric', 
            month: 'long', 
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
          })}
        </p>
      </div>
    </div>
  );
}
