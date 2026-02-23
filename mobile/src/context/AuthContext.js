import React, { createContext, useState, useContext, useEffect } from 'react';
import { getToken, saveToken, removeToken } from '../api/client';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [isLoading, setIsLoading] = useState(true);
  const [userToken, setUserToken] = useState(null);
  const [user, setUser] = useState(null);

  useEffect(() => {
    // Check if user is already logged in
    checkLoginState();
  }, []);

  const checkLoginState = async () => {
    try {
      const token = await getToken();
      if (token) {
        // Decode token to get user info (basic JWT decode)
        const payload = JSON.parse(atob(token.split('.')[1]));
        setUser({ email: payload.email, name: payload.name, is_admin: payload.is_admin });
        setUserToken(token);
      }
    } catch (e) {
      console.log('Error checking login state:', e);
    } finally {
      setIsLoading(false);
    }
  };

  const login = async (token) => {
    try {
      await saveToken(token);
      const payload = JSON.parse(atob(token.split('.')[1]));
      setUser({ email: payload.email, name: payload.name, is_admin: payload.is_admin });
      setUserToken(token);
    } catch (e) {
      console.log('Error saving token:', e);
      throw e;
    }
  };

  const logout = async () => {
    try {
      await removeToken();
      setUserToken(null);
      setUser(null);
    } catch (e) {
      console.log('Error logging out:', e);
    }
  };

  return (
    <AuthContext.Provider value={{ 
      isLoading, 
      userToken, 
      user, 
      login, 
      logout,
      isLoggedIn: !!userToken 
    }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

export default AuthContext;

