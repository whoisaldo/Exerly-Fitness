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
import AICoach     from './Components/Dashboard/AICoach';
import NewAICoach  from './Components/AICoach/AICoach';
import Onboarding  from './Components/Onboarding/Onboarding';
import Credits     from './Components/Credits';
import Admin       from './Components/Admin/Admin';
import AIErrorManager from './Components/Admin/AIErrorManager';
import LandingPage from './Components/LandingPage';
import MaintenanceNotice from './Components/MaintenanceNotice';
import MaintenanceHistory from './Components/MaintenanceHistory';
import StatusCheck from './Components/StatusCheck';
import AdminStatusChecker from './Components/AdminStatusChecker';
import MaintenanceIcon from './Components/MaintenanceIcon';

// Enhanced JWT decoder with better error handling
function decodeJWT(token) {
  try {
    const base64Url = token.split('.')[1];
    const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
    return JSON.parse(decodeURIComponent(
      atob(base64).split('').map(c => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2)).join('')
    ));
  } catch { 
    return null; 
  }
}

// Enhanced admin route protection
function AdminRoute({ children }) {
  const token = localStorage.getItem('token');
  if (!token) return <Navigate to="/" replace />;

  const payload = decodeJWT(token);
  if (!payload?.email) return <Navigate to="/" replace />;

  const email = payload.email.toLowerCase();
  const isAdmin = payload.is_admin || 
    (process.env.REACT_APP_ADMIN_EMAILS || '')
      .toLowerCase()
      .split(',')
      .map(s => s.trim())
      .filter(Boolean)
      .includes(email);

  if (!isAdmin) return <Navigate to="/dashboard" replace />;

  return children;
}

// Protected route wrapper
function ProtectedRoute({ children }) {
  const token = localStorage.getItem('token');
  if (!token) return <Navigate to="/" replace />;
  
  const payload = decodeJWT(token);
  if (!payload?.email) return <Navigate to="/" replace />;
  
  return children;
}

export default function App() {
  // Show maintenance notice on GitHub Pages deployment
  // To disable: remove this check or set REACT_APP_MAINTENANCE=false
  const isGitHubPages = window.location.hostname.includes('github.io');
  //const maintenanceMode = process.env.REACT_APP_MAINTENANCE !== 'false' && isGitHubPages;
  const maintenanceMode = false;
  // Show maintenance notice if enabled
  if (maintenanceMode) {
    return <MaintenanceNotice />;
  }

  return (
    <Router>
      <div className="app">
        <MaintenanceIcon />
        <Routes>
          {/* Public Routes */}
          <Route path="/" element={<LandingPage />} />
          <Route path="/login" element={<LoginSignup />} />
          <Route path="/credits" element={<Credits />} />
          <Route path="/maintenance-history" element={<MaintenanceHistory />} />
          <Route path="/status-check" element={<StatusCheck />} />
          
          {/* Protected Routes */}
          <Route path="/dashboard" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
          <Route path="/dashboard/profile" element={<ProtectedRoute><Profile /></ProtectedRoute>} />
          <Route path="/dashboard/workouts" element={<ProtectedRoute><Workouts /></ProtectedRoute>} />
          <Route path="/dashboard/activities" element={<ProtectedRoute><Activities /></ProtectedRoute>} />
          <Route path="/dashboard/food" element={<ProtectedRoute><Food /></ProtectedRoute>} />
          <Route path="/dashboard/goals" element={<ProtectedRoute><Goals /></ProtectedRoute>} />
          <Route path="/dashboard/sleep" element={<ProtectedRoute><Sleep /></ProtectedRoute>} />
          <Route path="/dashboard/ai-coach" element={<ProtectedRoute><NewAICoach /></ProtectedRoute>} />
          <Route path="/onboarding" element={<ProtectedRoute><Onboarding /></ProtectedRoute>} />
          
          {/* Admin Routes */}
          <Route path="/dashboard/admin" element={<AdminRoute><Admin /></AdminRoute>} />
          <Route path="/dashboard/admin/status" element={<AdminRoute><AdminStatusChecker /></AdminRoute>} />
          <Route path="/dashboard/admin/ai-errors" element={<AdminRoute><AIErrorManager /></AdminRoute>} />
          
          {/* Fallback */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </div>
    </Router>
  );
}