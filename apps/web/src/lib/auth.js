// Shared auth helpers for the web app.

// Clear the stored session token and send the user to the public landing page.
// Use this for both "no token" guards and 401 responses so an invalid/expired
// token is never left behind in localStorage (which would otherwise let
// ProtectedRoute bounce the user straight back into a 401 loop).
export function logout(navigate) {
  localStorage.removeItem('token');
  navigate('/');
}
