import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';

const Dashboard = () => {
  const [stats, setStats] = useState([]);
  const navigate = useNavigate();

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) {
      // no token → send back to login
      return navigate('/');
    }
    // fetch dashboard data with the token…
    fetch('/api/dashboard-data', {
      headers: { Authorization: 'Bearer ' + token }
    })
      .then(res => {
        if (res.status === 401) {
          // token invalid/expired → force logout
          handleLogout();
        } else {
          return res.json();
        }
      })
      .then(data => data && setStats(data))
      .catch(() => handleLogout());
  }, [navigate]);

  const handleLogout = () => {
    // 1. Remove the JWT
    localStorage.removeItem('token');
    // 2. Redirect to login
    navigate('/');
  };

  return (
    <div className="container">
      {/* … your header and stats grid … */}
      <button className="submit" onClick={handleLogout}>
        Logout
      </button>
      {/* … */}
    </div>
  );
};

export default Dashboard;
