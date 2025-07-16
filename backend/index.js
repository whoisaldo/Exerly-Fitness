// backend/index.js

const express = require('express');
const cors    = require('cors');
const bcrypt  = require('bcrypt');
const jwt     = require('jsonwebtoken');

const app    = express();
const SECRET = 'replace_this_with_a_real_secret';

app.use(cors());
app.use(express.json());

// In-memory user store for demo
const users = [];

// Health check
app.get('/ping', (_req, res) => res.send('pong'));

// Sign up
app.post('/signup', async (req, res) => {
  const { name, email, password } = req.body;
  if (!name || !email || !password) {
    return res.status(400).json({ message: 'Name, email, and password required' });
  }
  if (users.find(u => u.email === email)) {
    return res.status(409).json({ message: 'User already exists' });
  }
  const hash = await bcrypt.hash(password, 10);
  users.push({ name, email, hash });
  res.json({ message: 'Signup successful' });
});

// Login
app.post('/login', async (req, res) => {
  const { email, password } = req.body;
  const user = users.find(u => u.email === email);
  if (!user) {
    return res.status(401).json({ message: 'Invalid credentials' });
  }
  const valid = await bcrypt.compare(password, user.hash);
  if (!valid) {
    return res.status(401).json({ message: 'Invalid credentials' });
  }
  const token = jwt.sign({ email: user.email, name: user.name }, SECRET, { expiresIn: '1h' });
  res.json({ token });
});

// Middleware to protect routes
function authenticate(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth) return res.status(401).json({ message: 'No token provided' });
  const token = auth.split(' ')[1];
  try {
    const payload = jwt.verify(token, SECRET);
    req.user = payload;
    next();
  } catch (err) {
    return res.status(401).json({ message: 'Invalid or expired token' });
  }
}

// Protected dashboard-data endpoint
app.get('/api/dashboard-data', authenticate, (_req, res) => {
  // You can personalize this using req.user if you want
  res.json([
    { label: 'Total Workouts',  value: 24 },
    { label: 'Calories Burned', value: '1,560 kcal' },
    { label: 'Active Goals',    value: 3 },
  ]);
});

// Start server
const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`🟢 Server running on http://localhost:${PORT}`));
