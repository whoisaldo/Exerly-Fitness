// frontend/src/App.js
import React from 'react';
import { HashRouter as Router, Routes, Route, Navigate } from 'react-router-dom';

import LoginSignup from './Components/LoginSignup/LoginSignup';
import Dashboard   from './Components/Dashboard/Dashboard';
import Workouts    from './Components/Dashboard/Workouts';
import Activities  from './Components/Dashboard/Activities';
import Food        from './Components/Dashboard/Food';
import Goals       from './Components/Dashboard/Goals';
import Sleep       from './Components/Dashboard/Sleep';
import Profile     from './Components/Dashboard/Profile';
import Credits     from './Components/Credits';
import Admin       from './Components/Admin/Admin';

// --- tiny jwt decoder (no deps) ---
function decodeJWT(token) {
  try {
    const base64Url = token.split('.')[1];
    const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
    return JSON.parse(decodeURIComponent(
      atob(base64).split('').map(c => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2)).join('')
    ));
  } catch { return null; }
}

const ADMIN_EMAILS = ['whois.younes@gmail.com']; // <— your admin list (lowercase)

function AdminRoute({ children }) {
  const token = localStorage.getItem('token');
  if (!token) return <Navigate to="/" replace />;

  const email = (decodeJWT(token)?.email || '').toLowerCase();
  if (!ADMIN_EMAILS.includes(email)) return <Navigate to="/dashboard" replace />;

  return children;
}

export default function App() {
  return (
    <Router>
      <Routes>
        <Route path="/"                     element={<LoginSignup />} />
        <Route path="/dashboard"            element={<Dashboard />} />
        <Route path="/dashboard/profile"    element={<Profile />} />
        <Route path="/dashboard/workouts"   element={<Workouts />} />
        <Route path="/dashboard/activities" element={<Activities />} />
        <Route path="/dashboard/food"       element={<Food />} />
        <Route path="/dashboard/goals"      element={<Goals />} />
        <Route path="/dashboard/hours"      element={<Sleep />} />
        <Route path="/dashboard/sleep"      element={<Sleep />} />
        <Route path="/dashboard/admin"      element={
          <AdminRoute><Admin /></AdminRoute>
        } />
        <Route path="/credits"              element={<Credits />} />
      </Routes>
    </Router>
  );
}