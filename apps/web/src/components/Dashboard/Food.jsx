import React from 'react';
import { Navigate, useLocation } from 'react-router-dom';

export default function Food() {
  const { search } = useLocation();
  return <Navigate to={`/dashboard/diary${search}`} replace />;
}
