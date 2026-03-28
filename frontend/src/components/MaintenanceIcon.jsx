import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import './MaintenanceIcon.css';

export default function MaintenanceIcon() {
  const [isVisible, setIsVisible] = useState(true);

  if (!isVisible) return null;

  return (
    <div className="maintenance-icon-container">
      <Link to="/maintenance-history" className="maintenance-icon" title="Maintenance History">
        🔧
      </Link>
      <button 
        className="close-maintenance-icon" 
        onClick={() => setIsVisible(false)}
        title="Close"
      >
        ×
      </button>
    </div>
  );
}
