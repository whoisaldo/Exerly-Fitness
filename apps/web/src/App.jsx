// frontend/src/App.jsx
import React, { lazy, Suspense } from 'react';
import {
  HashRouter as Router,
  Routes,
  Route,
  Navigate,
  useLocation,
  useNavigate,
} from 'react-router-dom';
import { installSessionGuard, useSession, useSessionScope } from './hooks/useSession';
import { AccountCalendarProvider } from './hooks/useAccountCalendar';
import { FoodSync } from './hooks/useFoods';
import { AppShell } from './components/ui/AppShell';
import { ConnectionStatus } from './components/ui/ConnectionStatus';
import { dismissSessionNotice, getSessionNotice, subscribeToSession } from './lib/sessionStorage';

import LoginSignup from './components/LoginSignup/LoginSignup';
import Dashboard from './components/Dashboard/Dashboard';
import Workouts from './components/Dashboard/Workouts';
import Activities from './components/Dashboard/Activities';
import Food from './components/Dashboard/Food';
import Goals from './components/Dashboard/Goals';
import Sleep from './components/Dashboard/Sleep';
import Profile from './components/Dashboard/Profile';
import Onboarding from './components/Onboarding/Onboarding';
import Credits from './components/Credits';
import AIErrorManager from './components/Admin/AIErrorManager';
import LandingPage from './components/LandingPage';
import MaintenanceHistory from './components/MaintenanceHistory';
import StatusCheck from './components/StatusCheck';
import AdminStatusChecker from './components/AdminStatusChecker';

const NewAICoach = lazy(() => import('./components/AICoach/AICoach'));
const Admin = lazy(() => import('./components/Admin/Admin'));
const Diary = lazy(() => import('./components/Diary/Diary'));
const WeightPage = lazy(() => import('./components/Weight/WeightPage'));
const ProgramPage = lazy(() => import('./components/Program/ProgramPage'));

const LazyFallback = () => (
  <div className="min-h-screen bg-deep flex items-center justify-center">
    <div className="h-8 w-8 animate-spin rounded-full border-2 border-primary border-t-transparent" />
  </div>
);

// Redirect after refresh confirms that the saved session is no longer valid.
function SessionGuard() {
  const navigate = useNavigate();
  const scope = useSessionScope();
  const notice = React.useSyncExternalStore(subscribeToSession, getSessionNotice, () => null);
  React.useEffect(() => {
    installSessionGuard(navigate);
  }, [navigate]);
  if (scope || !notice) return null;
  return (
    <div className="flex items-center justify-between gap-4 border-b border-border-subtle bg-surface-1 px-4 py-2">
      <p role="status" className="text-pretty text-sm text-slate-200">
        {JSON.parse(notice).message}
      </p>
      <button
        type="button"
        onClick={dismissSessionNotice}
        className="min-h-11 rounded-lg px-3 text-sm text-slate-200"
      >
        Dismiss
      </button>
    </div>
  );
}

// Reset scroll position on route change (HashRouter preserves scroll otherwise)
function ScrollToTop() {
  const { pathname } = useLocation();
  React.useEffect(() => {
    window.scrollTo(0, 0);
  }, [pathname]);
  return null;
}

function AdminRoute({ children }) {
  const { user } = useSession();
  if (!user?.isAdmin) return <Navigate to="/dashboard" replace />;
  return children;
}

function ProtectedRoute({ children }) {
  const scope = useSessionScope();
  const { pathname } = useLocation();
  const { user, setup, loading, error, retry } = useSession();
  if (!scope) return <Navigate to="/" replace />;
  if (loading)
    return (
      <AppShell>
        <p role="status">Loading your account…</p>
      </AppShell>
    );
  if (error || !user)
    return (
      <AppShell>
        <div role="alert" className="rounded-xl border border-border-subtle p-5">
          <p className="text-pretty">
            {error || 'Could not load your account. Your saved changes are still here.'}
          </p>
          <button
            type="button"
            onClick={retry}
            className="mt-4 min-h-11 rounded-lg bg-primary px-4 text-white"
          >
            Retry account
          </button>
        </div>
      </AppShell>
    );
  if (!setup?.complete && pathname !== '/onboarding') return <Navigate to="/onboarding" replace />;
  if (setup?.complete && pathname === '/onboarding') return <Navigate to="/dashboard" replace />;
  return (
    <AccountCalendarProvider key={scope} timeZone={user.timezone}>
      <FoodSync account={user._id} scope={scope} />
      {children}
    </AccountCalendarProvider>
  );
}

export default function App() {
  return (
    <Router>
      <ScrollToTop />
      <SessionGuard />
      <ConnectionStatus />
      <>
        <Routes>
          {/* Public Routes */}
          <Route path="/" element={<LandingPage />} />
          <Route path="/login" element={<LoginSignup />} />
          <Route path="/credits" element={<Credits />} />
          <Route path="/maintenance-history" element={<MaintenanceHistory />} />
          <Route path="/status-check" element={<StatusCheck />} />

          {/* Protected Routes */}
          <Route
            path="/dashboard"
            element={
              <ProtectedRoute>
                <Dashboard />
              </ProtectedRoute>
            }
          />
          <Route
            path="/dashboard/profile"
            element={
              <ProtectedRoute>
                <Profile />
              </ProtectedRoute>
            }
          />
          <Route
            path="/dashboard/workouts"
            element={
              <ProtectedRoute>
                <Workouts />
              </ProtectedRoute>
            }
          />
          <Route
            path="/dashboard/activities"
            element={
              <ProtectedRoute>
                <Activities />
              </ProtectedRoute>
            }
          />
          <Route
            path="/dashboard/food"
            element={
              <ProtectedRoute>
                <Food />
              </ProtectedRoute>
            }
          />
          <Route
            path="/dashboard/diary"
            element={
              <ProtectedRoute>
                <Suspense fallback={<LazyFallback />}>
                  <Diary />
                </Suspense>
              </ProtectedRoute>
            }
          />
          <Route
            path="/dashboard/weight"
            element={
              <ProtectedRoute>
                <Suspense fallback={<LazyFallback />}>
                  <WeightPage />
                </Suspense>
              </ProtectedRoute>
            }
          />
          <Route
            path="/dashboard/program"
            element={
              <ProtectedRoute>
                <Suspense fallback={<LazyFallback />}>
                  <ProgramPage />
                </Suspense>
              </ProtectedRoute>
            }
          />
          <Route
            path="/dashboard/goals"
            element={
              <ProtectedRoute>
                <Goals />
              </ProtectedRoute>
            }
          />
          <Route
            path="/dashboard/sleep"
            element={
              <ProtectedRoute>
                <Sleep />
              </ProtectedRoute>
            }
          />
          <Route
            path="/dashboard/ai-coach"
            element={
              <ProtectedRoute>
                <Suspense fallback={<LazyFallback />}>
                  <NewAICoach />
                </Suspense>
              </ProtectedRoute>
            }
          />
          <Route
            path="/onboarding"
            element={
              <ProtectedRoute>
                <Onboarding />
              </ProtectedRoute>
            }
          />

          {/* Admin Routes */}
          <Route
            path="/dashboard/admin"
            element={
              <AdminRoute>
                <Suspense fallback={<LazyFallback />}>
                  <Admin />
                </Suspense>
              </AdminRoute>
            }
          />
          <Route
            path="/dashboard/admin/status"
            element={
              <AdminRoute>
                <AdminStatusChecker />
              </AdminRoute>
            }
          />
          <Route
            path="/dashboard/admin/ai-errors"
            element={
              <AdminRoute>
                <AIErrorManager />
              </AdminRoute>
            }
          />

          {/* Fallback */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </>
    </Router>
  );
}
