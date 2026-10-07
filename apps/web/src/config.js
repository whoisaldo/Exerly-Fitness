// API base URL resolution.
//
// The old version only recognised "localhost" and "127.0.0.1" as development.
// Opening the dev server over the tailnet (http://100.80.149.7:3000) therefore
// fell through to the production URL, so a local UI silently talked to the
// deployed API. Any private or loopback host now points at the API on the same
// machine.

const PRIVATE_HOST = [
  /^localhost$/,
  /^127\.\d+\.\d+\.\d+$/,
  /^\[?::1\]?$/,
  /^192\.168\.\d+\.\d+$/,
  /^10\.\d+\.\d+\.\d+$/,
  /^172\.(1[6-9]|2\d|3[01])\.\d+\.\d+$/,
  // Tailscale hands out addresses in the 100.64.0.0/10 CGNAT range.
  /^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.\d+\.\d+$/,
  /\.ts\.net$/,
  /^[a-z0-9-]+\.local$/,
];

const API_PORT = import.meta.env.VITE_API_PORT || '3001';
const hostname = window.location.hostname;
const isPrivateHost = PRIVATE_HOST.some((pattern) => pattern.test(hostname));

// An explicit VITE_API_URL always wins, so a preview build can point anywhere.
const BASE_URL =
  import.meta.env.VITE_API_URL ||
  (isPrivateHost
    ? `${window.location.protocol}//${hostname}:${API_PORT}`
    : 'https://exerly-fitness-93dyl.ondigitalocean.app');

const API_CONFIG = { BASE_URL, isPrivateHost };

export default API_CONFIG;
