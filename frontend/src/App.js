// frontend/src/App.js
import React from 'react';
import Credits from './Components/Credits';
import { HashRouter as Router, Routes, Route } from 'react-router-dom';

import LoginSignup from './Components/LoginSignup/LoginSignup';
import Dashboard   from './Components/Dashboard/Dashboard';
import Workouts    from './Components/Dashboard/Workouts';
import Activities  from './Components/Dashboard/Activities';
import Food        from './Components/Dashboard/Food';
import Goals       from './Components/Dashboard/Goals';
import Hours       from './Components/Dashboard/Hours';
import Sleep from './Components/Dashboard/Sleep';

export default function App() {
  return (
    <Router>
      <Routes>
        <Route path="/"                         element={<LoginSignup />} />
        <Route path="/dashboard"                element={<Dashboard />} />
        <Route path="/dashboard/workouts"       element={<Workouts />} />
        <Route path="/dashboard/activities"     element={<Activities />} />
        <Route path="/dashboard/food"           element={<Food />} />
        <Route path="/dashboard/goals"          element={<Goals />} />
        <Route path="/dashboard/hours"          element={<Hours />} />
        <Route path="/credits"                  element={<Credits />} />
        <Route path="/dashboard/sleep"          element={<Sleep />} />
      </Routes>
    </Router>
  );
}
