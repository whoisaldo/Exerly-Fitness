// frontend/src/Components/Dashboard/Dashboard.jsx
import React, { useEffect, useState } from 'react';
import { Link, useNavigate }           from 'react-router-dom';
import '../LoginSignup/LoginSignup.css';
import './Dashboard.css';
const BASE_URL = 'https://powerful-citadel-83317-b198c7aed44f.herokuapp.com';


export default function Dashboard() {
  const [stats, setStats] = useState([]);
  const navigate = useNavigate();

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (!token) return navigate('/');
    fetch(`${BASE_URL}/api/dashboard-data`, {
      headers: { Authorization: 'Bearer ' + token }
    })
      .then(res => {
        if (res.status === 401) {
          navigate('/'); throw new Error('Unauthorized');
        }
        return res.json();
      })
      .then(data => setStats(data))
      .catch(console.error);
  }, [navigate]);

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
        <button className="submit" onClick={handleLogout}>Logout</button>
      </div>

      <div className="stats-grid">
        {stats.map(({ label, value, route }) => (
          <Link to={route} key={label} className="stats-card">
            <div className="stats-card-label">{label}</div>
            <div className="stats-card-value">{value}</div>
          </Link>
        ))}
      </div>
    </div>
  );
}
