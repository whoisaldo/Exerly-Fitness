import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import '../LoginSignup/LoginSignup.css';
import './Dashboard.css';

// Demo data with routes
const placeholderStats = [
  { label: 'Total Workouts', value: 36, route: '/dashboard/workouts' },
  { label: 'Calories Burned', value: '1,560 kcal', route: '/dashboard/calories' },
  { label: 'Active Goals', value: 3, route: '/dashboard/goals' },
  { label: 'Hours Worked Out', value: 43, route: '/dashboard/hours' },
];

const Dashboard = () => {
  const [stats] = useState(placeholderStats);
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
        <div className="text">Welcome Ali!</div>
        <button className="submit" onClick={handleLogout}>
          Logout
        </button>
      </div>

      <div className="stats-grid">
        {stats.map(({ label, value, route }) => (
          <Link to={route} key={label} className="stats-card">
            <div>
              <div className="stats-card-label">{label}</div>
              <div className="stats-card-value">{value}</div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  );
};

export default Dashboard;
