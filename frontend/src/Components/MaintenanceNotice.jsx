import React from 'react';
import './MaintenanceNotice.css';

export default function MaintenanceNotice() {
  return (
    <div className="maintenance-overlay">
      <div className="maintenance-container">
        <div className="maintenance-icon">🔧</div>
        <h1 className="maintenance-title">Under Maintenance</h1>
        <p className="maintenance-message">
          We're currently routing our database to a different cloud service for improved performance and reliability.
        </p>
        <p className="maintenance-submessage">
          The app will be back online shortly. Thank you for your patience!
        </p>
        <div className="maintenance-status">
          <div className="status-indicator"></div>
          <span>Working on it...</span>
        </div>
        <p className="maintenance-contact">
          Questions? Contact us at{' '}
          <a href="mailto:aliyounes@eternalreverse.com">aliyounes@eternalreverse.com</a>
        </p>
      </div>
    </div>
  );
}

