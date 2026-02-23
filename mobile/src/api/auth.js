// Authentication API functions
import apiClient, { saveToken, removeToken } from './client';
import API_CONFIG from '../config';

const { ENDPOINTS } = API_CONFIG;

/**
 * Login user
 * @param {string} email 
 * @param {string} password 
 * @returns {Promise<{token: string}>}
 */
export const login = async (email, password) => {
  const response = await apiClient.post(ENDPOINTS.AUTH.LOGIN, { 
    email, 
    password 
  });
  
  if (response.data.token) {
    await saveToken(response.data.token);
  }
  
  return response.data;
};

/**
 * Register new user
 * @param {string} name 
 * @param {string} email 
 * @param {string} password 
 * @returns {Promise<{message: string, token: string}>}
 */
export const signup = async (name, email, password) => {
  const response = await apiClient.post(ENDPOINTS.AUTH.SIGNUP, { 
    name, 
    email, 
    password 
  });
  
  if (response.data.token) {
    await saveToken(response.data.token);
  }
  
  return response.data;
};

/**
 * Logout user - clears stored token
 */
export const logout = async () => {
  await removeToken();
};

