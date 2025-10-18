import React, { useState } from 'react';
import './AIMaintenanceNotice.css';

export default function AIMaintenanceNotice() {
  const [dismissed, setDismissed] = useState(false);

  if (dismissed) return null;

  return (
    <div className="ai-maintenance-banner">
      <div className="ai-maintenance-content">
        <div className="ai-maintenance-icon">⚙️</div>
        <div className="ai-maintenance-text">
          <h3 className="ai-maintenance-title">AI Coach Maintenance</h3>
          <p className="ai-maintenance-message">
            We're working on improving the AI Coach feature. It may not be fully functional at the moment. 
            Thank you for your patience!
          </p>
        </div>
        <button 
          className="ai-maintenance-close"
          onClick={() => setDismissed(true)}
          aria-label="Dismiss notification"
        >
          ✕
        </button>
      </div>
    </div>
  );
}
