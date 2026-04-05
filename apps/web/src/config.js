// API Configuration
// Automatically detects if running locally or in production

const isLocalDevelopment = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';

const API_CONFIG = {
  // For local development, use localhost:3001
  // For production (GitHub Pages/Heroku), use the environment variable or a default production URL
  BASE_URL: isLocalDevelopment
    ? 'http://localhost:3001'
    : (import.meta.env.VITE_API_URL || 'https://exerly-fitness-93dyl.ondigitalocean.app')
};

export default API_CONFIG;

