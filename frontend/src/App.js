import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import LoginSignup from './Components/LoginSignup/LoginSignup';
import Dashboard from './Components/Dashboard/Dashboard';
import Workouts from './Components/Dashboard/Workouts';
import Calories from './Components/Dashboard/Calories';
import Goals from './Components/Dashboard/Goals';
import Hours from './Components/Dashboard/Hours';

const App = () => {
  return (
    <Router>
      <Routes>
        <Route path="/" element={<LoginSignup />} />
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/dashboard/workouts" element={<Workouts />} />
        <Route path="/dashboard/calories" element={<Calories />} />
        <Route path="/dashboard/goals" element={<Goals />} />
        <Route path="/dashboard/hours" element={<Hours />} />
      </Routes>
    </Router>
  );
};

export default App;
