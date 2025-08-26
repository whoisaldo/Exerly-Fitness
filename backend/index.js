// backend/index.js
const express = require('express');
const cors = require('cors');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');

const app = express();
const SECRET = process.env.JWT_SECRET || 'fallback-secret';
const ADMIN_EMAIL = (process.env.ADMIN_EMAIL || '').toLowerCase();

// ---------- DB ----------
const pool = new Pool({
  connectionString: process.env.DATABASE_URL || undefined,
  ssl: process.env.DATABASE_URL ? { rejectUnauthorized: false } : false,
});

// Centralized DB query helper to ensure parameterization and error logging
async function dbQuery(query, params) {
  try {
    return await pool.query(query, params);
  } catch (err) {
    console.error('DB Error:', err);
    throw err;
  }
}

// Ensure the configured admin exists and is marked as admin
async function ensureAdmin() {
  if (!ADMIN_EMAIL) return;
  try {
    await dbQuery(`UPDATE users SET is_admin=true WHERE lower(email)=lower($1)`, [ADMIN_EMAIL]);
  } catch (e) {
    console.error('ensureAdmin error:', e.message);
  }
}

async function initDb() {
  await dbQuery(`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL,
      hash TEXT NOT NULL,
      profile JSONB
    );
  `);
  await dbQuery(`
    CREATE TABLE IF NOT EXISTS activities (
      id SERIAL PRIMARY KEY,
      email TEXT NOT NULL,
      activity TEXT NOT NULL,
      duration_min INT NOT NULL,
      calories INT NOT NULL,
      entry_date DATE NOT NULL
    );
  `);
  await dbQuery(`
    CREATE TABLE IF NOT EXISTS food (
      id SERIAL PRIMARY KEY,
      email TEXT NOT NULL,
      name TEXT NOT NULL,
      calories INT NOT NULL,
      protein INT NOT NULL,
      sugar INT NOT NULL,
      entry_date DATE NOT NULL
    );
  `);
  await dbQuery(`
    CREATE TABLE IF NOT EXISTS sleep (
      id SERIAL PRIMARY KEY,
      email TEXT NOT NULL,
      hours NUMERIC NOT NULL,
      quality TEXT NOT NULL,
      entry_date DATE NOT NULL
    );
  `);

  await dbQuery(`ALTER TABLE users ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();`);
  await dbQuery(`ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;`);
  await dbQuery(`ALTER TABLE activities ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();`);
  await dbQuery(`ALTER TABLE food ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();`);
  await dbQuery(`ALTER TABLE sleep ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();`);

  // Helpful indexes
  await dbQuery(`CREATE INDEX IF NOT EXISTS idx_activities_email_date ON activities(email, entry_date);`);
  await dbQuery(`CREATE INDEX IF NOT EXISTS idx_food_email_date ON food(email, entry_date);`);
  await dbQuery(`CREATE INDEX IF NOT EXISTS idx_sleep_email_date ON sleep(email, entry_date);`);

  // Ensure all required tables exist
  const tables = ['users', 'activities', 'food', 'sleep'];
  for (const t of tables) {
    const check = await dbQuery(`SELECT to_regclass($1)`, [t]);
    if (!check.rows[0].to_regclass) {
      throw new Error(`Table ${t} missing after init!`);
    }
  }
  console.log('✅ Database ready');
}
initDb()
  .then(ensureAdmin)
  .catch(err => {
    console.error('DB init error:', err);
    process.exit(1);
  });

// ---------- App ----------
const allowedOrigins = [
  'http://localhost:3000',
  'http://127.0.0.1:3000',
  'http://localhost:5173',
  'http://127.0.0.1:5173',
  'https://whoisaldo.github.io',
];
app.use(cors({
  origin: function (origin, callback) {
    // allow requests with no origin (like mobile apps or curl)
    if (!origin) return callback(null, true);
    if (allowedOrigins.indexOf(origin) !== -1) {
      return callback(null, true);
    } else {
      // Disallow silently (no thrown error) so preflights return cleanly
      return callback(null, false);
    }
  },
  credentials: true,
  optionsSuccessStatus: 204,
}));
app.use(express.json());

// Helper: calc maintenance calories
function calculateMaintenance(profile) {
  if (!profile) return null;
  const { age, sex, height_cm, weight_kg, activity_level } = profile;
  const s = sex === 'male' ? 5 : -161;
  const bmr = 10 * Number(weight_kg) + 6.25 * Number(height_cm) - 5 * Number(age) + s;
  const multiplier = {
    sedentary: 1.2, light: 1.375, moderate: 1.55, active: 1.725, 'very active': 1.9
  }[activity_level] || 1.2;
  return Math.round(bmr * multiplier);
}

// Helper: validate email
function validateEmail(email) {
  return typeof email === 'string' && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

// Helper: normalize date to YYYY-MM-DD in UTC
function toUTCDateString(date) {
  if (!date) return null;
  const d = new Date(date);
  return d.toISOString().slice(0, 10);
}

// Health check
app.get('/ping', (_req, res) => res.send('pong'));

// ---------- Auth ----------
app.post('/signup', async (req, res) => {
  try {
    let { name, email, password } = req.body;
    if (!name || !email || !password)
      return res.status(400).json({ message: 'Name, email & password required' });
    if (!validateEmail(email)) return res.status(400).json({ message: 'Invalid email format' });
    email = email.toLowerCase();
    const existing = await dbQuery('SELECT 1 FROM users WHERE email=$1', [email]);
    if (existing.rowCount > 0) return res.status(409).json({ message: 'User with this email already exists' });
    const hash = await bcrypt.hash(password, 10);
    const makeAdmin = ADMIN_EMAIL && email === ADMIN_EMAIL;
    await dbQuery('INSERT INTO users (name, email, hash, is_admin) VALUES ($1,$2,$3,$4)', [name, email, hash, !!makeAdmin]);
    // Instant login: create and return JWT token
    const token = jwt.sign({ email, name, is_admin: !!makeAdmin }, SECRET, { expiresIn: '12h' });
    res.json({ message: 'Signup successful', token });
  } catch (err) {
    res.status(500).json({ message: 'Signup failed', error: err.message });
  }
});

app.post('/login', async (req, res) => {
  try {
    let { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ message: 'Email and password required' });
    if (!validateEmail(email)) return res.status(400).json({ message: 'Invalid email format' });
    email = email.toLowerCase();
    const r = await dbQuery('SELECT * FROM users WHERE email=$1', [email]);
    const user = r.rows[0];
    if (!user) return res.status(401).json({ message: 'Invalid credentials' });
    const ok = await bcrypt.compare(password, user.hash);
    if (!ok) return res.status(401).json({ message: 'Invalid credentials' });
    // Auto-promote configured admin email if needed
    if (ADMIN_EMAIL && email === ADMIN_EMAIL && !user.is_admin) {
      await dbQuery('UPDATE users SET is_admin=true WHERE email=$1', [email]);
      user.is_admin = true;
    }
    const token = jwt.sign({ email: user.email, name: user.name, is_admin: !!user.is_admin }, SECRET, { expiresIn: '12h' });
    res.json({ token });
  } catch (err) {
    res.status(500).json({ message: 'Login failed', error: err.message });
  }
});

// ---------- Auth middleware ----------
function authenticate(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth) return res.status(401).json({ message: 'Authorization header missing. Please provide a Bearer token.' });
  const parts = auth.split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer') {
    return res.status(401).json({ message: 'Invalid authorization format. Use: Bearer <token>' });
  }
  const token = parts[1];
  try {
    req.user = jwt.verify(token, SECRET);
    next();
  } catch {
    res.status(401).json({ message: 'Invalid or expired token. Please log in again.' });
  }
}

function requireAdmin(req, res, next) {
  if (!req.user?.is_admin) return res.status(403).json({ message: 'Admin only' });
  next();
}



// ---------- Profile ----------
app.get('/api/profile', authenticate, async (req, res) => {
  try {
    const r = await dbQuery('SELECT profile, name, email FROM users WHERE email=$1', [req.user.email]);
    const u = r.rows[0];
    res.json(u?.profile || {});
  } catch (err) {
    res.status(500).json({ message: 'Error fetching profile', error: err.message });
  }
});

app.post('/api/profile', authenticate, async (req, res) => {
  try {
    const profile = req.body || {};
    await dbQuery('UPDATE users SET profile=$1 WHERE email=$2', [profile, req.user.email]);
    res.json({ message: 'Profile saved', profile });
  } catch (err) {
    res.status(500).json({ message: 'Error saving profile', error: err.message });
  }
});

// ---------- Activities ----------
app.get('/api/activities', authenticate, async (req, res) => {
  try {
    const r = await dbQuery(
      'SELECT * FROM activities WHERE email=$1 ORDER BY id DESC',
      [req.user.email]
    );
    // Dates as YYYY-MM-DD UTC
    r.rows.forEach(row => row.entry_date = toUTCDateString(row.entry_date));
    res.json(r.rows);
  } catch (err) {
    res.status(500).json({ message: 'Error fetching activities', error: err.message });
  }
});

app.post('/api/activities', authenticate, async (req, res) => {
  try {
    const { activity, duration_min, calories } = req.body;
    if (!activity || duration_min == null || calories == null)
      return res.status(400).json({ message: 'Activity, duration (min), and calories are required' });
    if (typeof activity !== 'string' || !activity.trim()) return res.status(400).json({ message: 'Invalid activity' });
    if (isNaN(Number(duration_min)) || Number(duration_min) <= 0) return res.status(400).json({ message: 'Duration must be positive number' });
    if (isNaN(Number(calories)) || Number(calories) < 0) return res.status(400).json({ message: 'Calories must be non-negative number' });
    const r = await dbQuery(
      `INSERT INTO activities (email, activity, duration_min, calories, entry_date)
       VALUES ($1,$2,$3,$4,(now() AT TIME ZONE 'utc')::date)
       RETURNING *`,
      [req.user.email, activity.trim(), Number(duration_min), Number(calories)]
    );
    r.rows[0].entry_date = toUTCDateString(r.rows[0].entry_date);
    res.status(201).json(r.rows[0]);
  } catch (err) {
    res.status(500).json({ message: 'Error logging activity', error: err.message });
  }
});

// ---------- Food ----------
app.get('/api/food', authenticate, async (req, res) => {
  try {
    const r = await dbQuery(
      'SELECT * FROM food WHERE email=$1 ORDER BY id DESC',
      [req.user.email]
    );
    r.rows.forEach(row => row.entry_date = toUTCDateString(row.entry_date));
    res.json(r.rows);
  } catch (err) {
    res.status(500).json({ message: 'Error fetching food logs', error: err.message });
  }
});

app.post('/api/food', authenticate, async (req, res) => {
  try {
    const { name, calories, protein, sugar } = req.body;
    if (!name || calories == null || protein == null || sugar == null)
      return res.status(400).json({ message: 'Name, calories, protein, and sugar are required' });
    if (typeof name !== 'string' || !name.trim()) return res.status(400).json({ message: 'Invalid food name' });
    if ([calories, protein, sugar].some(v => isNaN(Number(v)))) return res.status(400).json({ message: 'Calories, protein, and sugar must be numbers' });
    const r = await dbQuery(
      `INSERT INTO food (email, name, calories, protein, sugar, entry_date)
       VALUES ($1,$2,$3,$4,$5,(now() AT TIME ZONE 'utc')::date)
       RETURNING *`,
      [req.user.email, name.trim(), Number(calories), Number(protein), Number(sugar)]
    );
    r.rows[0].entry_date = toUTCDateString(r.rows[0].entry_date);
    res.status(201).json(r.rows[0]);
  } catch (err) {
    res.status(500).json({ message: 'Error logging food', error: err.message });
  }
});

// ---------- Sleep ----------
app.get('/api/sleep', authenticate, async (req, res) => {
  try {
    const r = await dbQuery(
      'SELECT * FROM sleep WHERE email=$1 ORDER BY id DESC',
      [req.user.email]
    );
    r.rows.forEach(row => row.entry_date = toUTCDateString(row.entry_date));
    res.json(r.rows);
  } catch (err) {
    res.status(500).json({ message: 'Error fetching sleep logs', error: err.message });
  }
});

app.post('/api/sleep', authenticate, async (req, res) => {
  try {
    const { hours, quality } = req.body;
    if (hours == null || !quality)
      return res.status(400).json({ message: 'Hours and quality are required' });
    if (isNaN(Number(hours)) || Number(hours) < 0) return res.status(400).json({ message: 'Hours must be a non-negative number' });
    if (typeof quality !== 'string' || !quality.trim()) return res.status(400).json({ message: 'Quality must be a non-empty string' });
    const r = await dbQuery(
      `INSERT INTO sleep (email, hours, quality, entry_date)
       VALUES ($1,$2,$3,(now() AT TIME ZONE 'utc')::date)
       RETURNING *`,
      [req.user.email, Number(hours), quality.trim()]
    );
    r.rows[0].entry_date = toUTCDateString(r.rows[0].entry_date);
    res.status(201).json(r.rows[0]);
  } catch (err) {
    res.status(500).json({ message: 'Error logging sleep', error: err.message });
  }
});

// ---------- Recent Logs Endpoint ----------
app.get('/api/recent', authenticate, async (req, res) => {
  try {
    const email = req.user.email;
    // Get all logs for today for each type, with a source field
    const [activities, food, sleep] = await Promise.all([
      dbQuery(
        `SELECT id, activity as name, duration_min, calories, entry_date, created_at, 'activity' as type, id as entry_id, null as protein, null as sugar, null as hours, null as quality
         FROM activities
         WHERE email=$1 AND entry_date=(now() AT TIME ZONE 'utc')::date
         ORDER BY id DESC`,
        [email]
      ),
      dbQuery(
        `SELECT id, name, null as duration_min, calories, entry_date, created_at, 'food' as type, id as entry_id, protein, sugar, null as hours, null as quality
         FROM food
         WHERE email=$1 AND entry_date=(now() AT TIME ZONE 'utc')::date
         ORDER BY id DESC`,
        [email]
      ),
      dbQuery(
        `SELECT id, null as name, null as duration_min, null as calories, entry_date, created_at, 'sleep' as type, id as entry_id, null as protein, null as sugar, hours, quality
         FROM sleep
         WHERE email=$1 AND entry_date=(now() AT TIME ZONE 'utc')::date
         ORDER BY id DESC`,
        [email]
      ),
    ]);
    let logs = [
      ...activities.rows.map(r => ({ ...r, entry_date: toUTCDateString(r.entry_date), entry_time: new Date(r.created_at).toISOString() })),
      ...food.rows.map(r => ({ ...r, entry_date: toUTCDateString(r.entry_date), entry_time: new Date(r.created_at).toISOString() })),
      ...sleep.rows.map(r => ({ ...r, entry_date: toUTCDateString(r.entry_date), entry_time: new Date(r.created_at).toISOString() })),
    ];
    // If created_at is not available, sort by id as fallback
    logs.sort((a, b) => {
      if (a.entry_time && b.entry_time) return b.entry_time.localeCompare(a.entry_time);
      return b.entry_id - a.entry_id;
    });
    res.json(logs);
  } catch (err) {
    res.status(500).json({ message: 'Error fetching recent logs', error: err.message });
  }
});

// ---------- Reset Today ----------
app.post('/api/reset-today', authenticate, async (req, res) => {
  try {
    const email = req.user.email;
    // Get what will be deleted for reporting
    const [acts, foods, sleeps] = await Promise.all([
      dbQuery(`SELECT * FROM activities WHERE email=$1 AND entry_date=(now() AT TIME ZONE 'utc')::date`, [email]),
      dbQuery(`SELECT * FROM food WHERE email=$1 AND entry_date=(now() AT TIME ZONE 'utc')::date`, [email]),
      dbQuery(`SELECT * FROM sleep WHERE email=$1 AND entry_date=(now() AT TIME ZONE 'utc')::date`, [email]),
    ]);
    const delA = await dbQuery(`DELETE FROM activities WHERE email=$1 AND entry_date=(now() AT TIME ZONE 'utc')::date`, [email]);
    const delF = await dbQuery(`DELETE FROM food WHERE email=$1 AND entry_date=(now() AT TIME ZONE 'utc')::date`, [email]);
    const delS = await dbQuery(`DELETE FROM sleep WHERE email=$1 AND entry_date=(now() AT TIME ZONE 'utc')::date`, [email]);
    res.json({
      message: 'Today\'s logs deleted',
      removed: {
        activities: acts.rows.map(r => ({ ...r, entry_date: toUTCDateString(r.entry_date) })),
        food: foods.rows.map(r => ({ ...r, entry_date: toUTCDateString(r.entry_date) })),
        sleep: sleeps.rows.map(r => ({ ...r, entry_date: toUTCDateString(r.entry_date) })),
      },
      counts: { activities: delA.rowCount, food: delF.rowCount, sleep: delS.rowCount }
    });
  } catch (err) {
    res.status(500).json({ message: 'Error resetting today\'s logs', error: err.message });
  }
});

// ---------- Admin (read-only users list, inspect entries, reset a user's today) ----------
app.get('/api/admin/users', authenticate, requireAdmin, async (_req, res) => {
  try {
    const r = await dbQuery(`SELECT id, name, email, created_at, is_admin FROM users ORDER BY id DESC`, []);
    res.json(r.rows);
  } catch (err) {
    res.status(500).json({ message: 'Error fetching users', error: err.message });
  }
});

app.get('/api/admin/user/:email/entries', authenticate, requireAdmin, async (req, res) => {
  try {
    let email = String(req.params.email || '').toLowerCase();
    if (!validateEmail(email)) return res.status(400).json({ message: 'Invalid email' });
    const [acts, foods, sleeps] = await Promise.all([
      dbQuery(`SELECT id, activity, duration_min, calories, entry_date, created_at FROM activities WHERE email=$1 ORDER BY id DESC`, [email]),
      dbQuery(`SELECT id, name, calories, protein, sugar, entry_date, created_at FROM food WHERE email=$1 ORDER BY id DESC`, [email]),
      dbQuery(`SELECT id, hours, quality, entry_date, created_at FROM sleep WHERE email=$1 ORDER BY id DESC`, [email]),
    ]);
    res.json({ activities: acts.rows, food: foods.rows, sleep: sleeps.rows });
  } catch (err) {
    res.status(500).json({ message: 'Error fetching user entries', error: err.message });
  }
});

app.post('/api/admin/user/:email/reset-today', authenticate, requireAdmin, async (req, res) => {
  try {
    let email = String(req.params.email || '').toLowerCase();
    if (!validateEmail(email)) return res.status(400).json({ message: 'Invalid email' });
    const [a, f, s] = await Promise.all([
      dbQuery(`DELETE FROM activities WHERE email=$1 AND entry_date=(now() AT TIME ZONE 'utc')::date`, [email]),
      dbQuery(`DELETE FROM food       WHERE email=$1 AND entry_date=(now() AT TIME ZONE 'utc')::date`, [email]),
      dbQuery(`DELETE FROM sleep      WHERE email=$1 AND entry_date=(now() AT TIME ZONE 'utc')::date`, [email]),
    ]);
    res.json({ message: 'User today reset', counts: { activities: a.rowCount, food: f.rowCount, sleep: s.rowCount } });
  } catch (err) {
    res.status(500).json({ message: 'Error resetting user today', error: err.message });
  }
});

// ---------- Dashboard data (cards) ----------
app.get('/api/dashboard-data', authenticate, async (req, res) => {
  try {
    const email = req.user.email;
    const [a, f, s, u] = await Promise.all([
      dbQuery(`SELECT calories FROM activities WHERE email=$1 AND entry_date=(now() AT TIME ZONE 'utc')::date`, [email]),
      dbQuery(`SELECT calories FROM food WHERE email=$1 AND entry_date=(now() AT TIME ZONE 'utc')::date`, [email]),
      dbQuery(`SELECT hours FROM sleep WHERE email=$1 AND entry_date=(now() AT TIME ZONE 'utc')::date`, [email]),
      dbQuery(`SELECT profile FROM users WHERE email=$1`, [email]),
    ]);
    const totalBurned = a.rows.reduce((sum, r) => sum + Number(r.calories), 0);
    const workoutCount = a.rowCount;
    const totalConsumed = f.rows.reduce((sum, r) => sum + Number(r.calories), 0);
    const totalSleepHours = s.rows.reduce((sum, r) => sum + Number(r.hours), 0);
    const maintenance = calculateMaintenance(u.rows[0]?.profile || null);
    const cards = [
      { label: 'Total Workouts', value: workoutCount, route: '/dashboard/activities' },
      { label: 'Calories Burned', value: `${totalBurned} kcal`, route: '/dashboard/activities' },
      { label: 'Calories Consumed', value: `${totalConsumed} kcal`, route: '/dashboard/food' },
      { label: 'Sleep (hrs)', value: `${totalSleepHours}`, route: '/dashboard/sleep' },
    ];
    // If admin, include Admin card
    if (req.user?.is_admin) {
      cards.unshift({ label: 'Admin', value: 'Open', route: '/dashboard/admin' });
    }
    if (maintenance) {
      const net = totalConsumed - totalBurned - maintenance;
      cards.push({ label: 'Maintenance (est.)', value: `${maintenance} kcal`, route: '/dashboard/profile' });
      cards.push({ label: 'Net vs. Maint.', value: `${net} kcal`, route: '/dashboard/food' });
    }
    res.json(cards);
  } catch (err) {
    res.status(500).json({ message: 'Error fetching dashboard data', error: err.message });
  }
});

// ---------- Start ----------
const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`🟢 Server running on http://localhost:${PORT}`));