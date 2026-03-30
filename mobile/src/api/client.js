// Axios API Client for Exerly Fitness Mobile App
import axios from 'axios';
import { Platform } from 'react-native';
import * as SecureStore from 'expo-secure-store';
import API_CONFIG from '../config';

// Web shim — SecureStore is native-only
const storage = Platform.OS === 'web'
  ? {
      getItemAsync: (key) => Promise.resolve(localStorage.getItem(key)),
      setItemAsync: (key, val) => { localStorage.setItem(key, val); return Promise.resolve(); },
      deleteItemAsync: (key) => { localStorage.removeItem(key); return Promise.resolve(); },
    }
  : SecureStore;

// Create axios instance with default config
const apiClient = axios.create({
  baseURL: API_CONFIG.BASE_URL,
  timeout: API_CONFIG.TIMEOUT,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Token storage keys
const TOKEN_KEY = 'exerly_auth_token';

// Token management functions
export const saveToken = async (token) => {
  await storage.setItemAsync(TOKEN_KEY, token);
};

export const getToken = async () => {
  return await storage.getItemAsync(TOKEN_KEY);
};

export const removeToken = async () => {
  await storage.deleteItemAsync(TOKEN_KEY);
};

// Request interceptor - adds auth token to requests
apiClient.interceptors.request.use(
  async (config) => {
    const token = await getToken();
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor - handles errors globally
apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    if (error.response) {
      // Handle 401 Unauthorized - token expired
      if (error.response.status === 401) {
        await removeToken();
        // You can dispatch a logout action or navigate to login here
      }
      
      // Handle other HTTP errors
      const message = error.response.data?.message || 'An error occurred';
      return Promise.reject(new Error(message));
    } else if (error.request) {
      // Network error - no response received
      return Promise.reject(new Error('Network error. Please check your connection.'));
    } else {
      return Promise.reject(error);
    }
  }
);

export default apiClient;

