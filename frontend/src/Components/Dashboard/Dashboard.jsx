import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import '../LoginSignup/LoginSignup.css';
import './Dashboard.css';

// Demo data 
const placeholderStats = [
  { label: 'Total Workouts',  value: 24 },
  { label: 'Calories Burned', value: '1,560 kcal' },
  { label: 'Active Goals',    value: 3 },
];

const Dashboard = () => {
  const [stats] = useState(placeholderStats);  //  with demo values
  const navigate = useNavigate();

  const handleLogout = () => {
    localStorage.removeItem('token');
    navigate('/');
  };

  return (
    <div className="container">
      <div className="header">
        <div className="text">Dashboard</div>
        <div className="underline"></div>
        <button className="submit" onClick={handleLogout}>
          Logout
        </button>
      </div>

      <div className="stats-grid">
        {stats.map(({ label, value }) => (
          <div key={label} className="stats-card">
            <div className="stats-card-label">{label}</div>
            <div className="stats-card-value">{value}</div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default Dashboard;
