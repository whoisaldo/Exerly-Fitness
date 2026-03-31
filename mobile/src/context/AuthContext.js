import React, { createContext, useState, useContext, useEffect } from 'react';
import { getToken, saveToken, removeToken } from '../api/client';

const AuthContext = createContext(null);
const BASE64_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';

function decodeBase64(base64) {
  let output = '';
  let index = 0;

  while (index < base64.length) {
    const encoded1 = BASE64_CHARS.indexOf(base64.charAt(index++));
    const encoded2 = BASE64_CHARS.indexOf(base64.charAt(index++));
    const encoded3 = BASE64_CHARS.indexOf(base64.charAt(index++));
    const encoded4 = BASE64_CHARS.indexOf(base64.charAt(index++));

    const charCode1 = (encoded1 << 2) | (encoded2 >> 4);
    const charCode2 = ((encoded2 & 15) << 4) | (encoded3 >> 2);
    const charCode3 = ((encoded3 & 3) << 6) | encoded4;

    output += String.fromCharCode(charCode1);

    if (encoded3 !== 64) {
      output += String.fromCharCode(charCode2);
    }

    if (encoded4 !== 64) {
      output += String.fromCharCode(charCode3);
    }
  }

  return output;
}

function decodeJwtPayload(token) {
  const payload = token?.split('.')[1];

  if (!payload) {
    return null;
  }

  const normalized = payload.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=');
  const decoded = typeof globalThis.atob === 'function'
    ? globalThis.atob(padded)
    : decodeBase64(padded);
  const json = decodeURIComponent(
    Array.from(decoded)
      .map((char) => `%${char.charCodeAt(0).toString(16).padStart(2, '0')}`)
      .join('')
  );

  return JSON.parse(json);
}

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
        const payload = decodeJwtPayload(token);

        if (!payload) {
          await removeToken();
          return;
        }

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
      const payload = decodeJwtPayload(token);

      if (!payload) {
        throw new Error('Invalid auth token');
      }

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
