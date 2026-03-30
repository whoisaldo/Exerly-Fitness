// API Configuration for Mobile App
// This file configures the API base URL for connecting to the backend

import Constants from 'expo-constants';

// Your local network IP address - UPDATE THIS if your IP changes
// Physical devices MUST use the actual IP (localhost won't work on phones)
const LOCAL_IP = '10.0.0.45'; // Your computer's local IP
const LOCAL_PORT = '3001';

// Production API URL (same as web)
const PRODUCTION_URL = 'https://powerful-citadel-83317-b198c7aed44f.herokuapp.com';

/**
 * Determines if running in development mode
 * In Expo, we can check the execution environment
 */
const isDevelopment = __DEV__;

/**
 * API Configuration Object
 * - Development: Uses local IP address so physical devices can reach the backend
 * - Production: Uses the deployed Heroku backend
 * 
 * IMPORTANT: localhost/127.0.0.1 will NOT work on physical iOS devices or Android emulators
 * You must use your computer's local network IP address (e.g., 192.168.x.x or 10.x.x.x)
 * 
 * To find your local IP:
 * - macOS: Run `ipconfig getifaddr en0` in terminal
 * - Windows: Run `ipconfig` and look for IPv4 Address
 * - Linux: Run `hostname -I` or `ip addr show`
 */
const API_CONFIG = {
  BASE_URL: isDevelopment 
    ? `http://${LOCAL_IP}:${LOCAL_PORT}` 
    : PRODUCTION_URL,
  
  // Timeout for API requests (in milliseconds)
  TIMEOUT: 30000,
  
  // Individual endpoint configurations (optional)
  ENDPOINTS: {
    AUTH: {
      LOGIN: '/login',
      SIGNUP: '/signup',
    },
    USER: {
      PROFILE: '/api/profile',
      ONBOARDING: '/api/user/onboarding',
    },
    ACTIVITIES: '/api/activities',
    FOOD: '/api/food',
    SLEEP: '/api/sleep',
    GOALS: '/api/goals',
    WORKOUTS: '/api/workouts',
    DASHBOARD: '/api/dashboard-data',
    AI: {
      CREDITS: '/api/ai/credits',
      PLANS: '/api/ai/plans',
      GENERATE: '/api/ai/generate',
    },
  },
};

export default API_CONFIG;

// Helper to get full URL for an endpoint
export const getApiUrl = (endpoint) => `${API_CONFIG.BASE_URL}${endpoint}`;

