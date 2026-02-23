// backend/index.js
const express = require('express');
const cors = require('cors');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
const sqlite3 = require('sqlite3').verbose();

const app = express();
const SECRET = process.env.JWT_SECRET || 'fallback-secret';
const ADMIN_EMAIL = (process.env.ADMIN_EMAIL || '').toLowerCase();

// ---------- DB ----------
// Use SQLite for local development if DATABASE_URL is not set, PostgreSQL for production
const USE_SQLITE = !process.env.DATABASE_URL;
let db;

if (USE_SQLITE) {
  console.log('🔵 Using SQLite for local development');
  db = new sqlite3.Database('./fitness.db', (err) => {
    if (err) console.error('SQLite connection error:', err);
    else console.log('✅ Connected to SQLite database');
  });
} else {
  console.log('🟢 Using PostgreSQL for production');
  db = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false }
  });
}

// Centralized DB query helper to work with both SQLite and PostgreSQL
async function dbQuery(query, params = []) {
  try {
    if (USE_SQLITE) {
      return new Promise((resolve, reject) => {
        // Convert PostgreSQL $1, $2 syntax to SQLite ? syntax
        const sqliteQuery = query.replace(/\$\d+/g, '?');
        
        if (sqliteQuery.trim().toUpperCase().startsWith('SELECT') || 
            sqliteQuery.trim().toUpperCase().includes('RETURNING')) {
          db.all(sqliteQuery, params, (err, rows) => {
            if (err) reject(err);
            else resolve({ rows, rowCount: rows.length });
          });
        } else {
          db.run(sqliteQuery, params, function(err) {
            if (err) reject(err);
            else resolve({ rows: [], rowCount: this.changes, lastID: this.lastID });
          });
        }
      });
    } else {
      return await db.query(query, params);
    }
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
  if (USE_SQLITE) {
    // SQLite initialization
    await dbQuery(`
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        hash TEXT NOT NULL,
        profile TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_admin INTEGER DEFAULT 0
      );
    `);
    await dbQuery(`
      CREATE TABLE IF NOT EXISTS activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL,
        activity TEXT NOT NULL,
        duration_min INTEGER NOT NULL,
        calories INTEGER NOT NULL,
        entry_date TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        intensity TEXT,
        type TEXT
      );
    `);
    await dbQuery(`
      CREATE TABLE IF NOT EXISTS food (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL,
        name TEXT NOT NULL,
        calories INTEGER NOT NULL,
        protein REAL NOT NULL,
        sugar REAL NOT NULL,
        entry_date TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        carbs REAL,
        fat REAL,
        meal_type TEXT
      );
    `);
    await dbQuery(`
      CREATE TABLE IF NOT EXISTS sleep (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL,
        hours REAL NOT NULL,
        quality TEXT NOT NULL,
        entry_date TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        bedtime TEXT,
        wake_time TEXT
      );
    `);
    await dbQuery(`
      CREATE TABLE IF NOT EXISTS goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL UNIQUE,
        daily_calories INTEGER,
        weekly_workouts INTEGER,
        daily_steps INTEGER,
        weekly_weight REAL,
        sleep_hours REAL,
        water_intake REAL,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      );
    `);
    await dbQuery(`
      CREATE TABLE IF NOT EXISTS workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL,
        name TEXT NOT NULL,
        exercises TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // Indexes
    await dbQuery(`CREATE INDEX IF NOT EXISTS idx_activities_email_date ON activities(email, entry_date);`);
    await dbQuery(`CREATE INDEX IF NOT EXISTS idx_food_email_date ON food(email, entry_date);`);
    await dbQuery(`CREATE INDEX IF NOT EXISTS idx_sleep_email_date ON sleep(email, entry_date);`);
    await dbQuery(`CREATE INDEX IF NOT EXISTS idx_workouts_email ON workouts(email);`);
  } else {
    // PostgreSQL initialization
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
    await dbQuery(`
      CREATE TABLE IF NOT EXISTS goals (
        id SERIAL PRIMARY KEY,
        email TEXT NOT NULL UNIQUE,
        daily_calories INT,
        weekly_workouts INT,
        daily_steps INT,
        weekly_weight NUMERIC,
        sleep_hours NUMERIC,
        water_intake NUMERIC,
        updated_at TIMESTAMPTZ DEFAULT now()
      );
    `);
    await dbQuery(`
      CREATE TABLE IF NOT EXISTS workouts (
        id SERIAL PRIMARY KEY,
        email TEXT NOT NULL,
        name TEXT NOT NULL,
        exercises JSONB,
        created_at TIMESTAMPTZ DEFAULT now(),
        updated_at TIMESTAMPTZ DEFAULT now()
      );
    `);

    await dbQuery(`ALTER TABLE users ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();`);
    await dbQuery(`ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;`);
    await dbQuery(`ALTER TABLE activities ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();`);
    await dbQuery(`ALTER TABLE activities ADD COLUMN IF NOT EXISTS intensity TEXT;`);
    await dbQuery(`ALTER TABLE activities ADD COLUMN IF NOT EXISTS type TEXT;`);
    await dbQuery(`ALTER TABLE food ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();`);
    await dbQuery(`ALTER TABLE food ADD COLUMN IF NOT EXISTS carbs NUMERIC;`);
    await dbQuery(`ALTER TABLE food ADD COLUMN IF NOT EXISTS fat NUMERIC;`);
    await dbQuery(`ALTER TABLE food ADD COLUMN IF NOT EXISTS meal_type TEXT;`);
    await dbQuery(`ALTER TABLE sleep ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();`);
    await dbQuery(`ALTER TABLE sleep ADD COLUMN IF NOT EXISTS bedtime TEXT;`);
    await dbQuery(`ALTER TABLE sleep ADD COLUMN IF NOT EXISTS wake_time TEXT;`);

    // Indexes
    await dbQuery(`CREATE INDEX IF NOT EXISTS idx_activities_email_date ON activities(email, entry_date);`);
    await dbQuery(`CREATE INDEX IF NOT EXISTS idx_food_email_date ON food(email, entry_date);`);
    await dbQuery(`CREATE INDEX IF NOT EXISTS idx_sleep_email_date ON sleep(email, entry_date);`);
    await dbQuery(`CREATE INDEX IF NOT EXISTS idx_workouts_email ON workouts(email);`);
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

// Helper: get today's date in YYYY-MM-DD format
function getTodayUTC() {
  return new Date().toISOString().slice(0, 10);
}

// Helper: handle profile data for SQLite vs PostgreSQL
function encodeProfile(profile) {
  if (USE_SQLITE) return JSON.stringify(profile);
  return profile;
}

function decodeProfile(profile) {
  if (USE_SQLITE && typeof profile === 'string') {
    try {
      return JSON.parse(profile);
    } catch {
      return null;
    }
  }
  return profile;
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
    res.json(decodeProfile(u?.profile) || {});
  } catch (err) {
    res.status(500).json({ message: 'Error fetching profile', error: err.message });
  }
});

app.post('/api/profile', authenticate, async (req, res) => {
  try {
    const profile = req.body || {};
    await dbQuery('UPDATE users SET profile=$1 WHERE email=$2', [encodeProfile(profile), req.user.email]);
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
    const { activity, duration_min, calories, intensity, type } = req.body;
    if (!activity || duration_min == null || calories == null)
      return res.status(400).json({ message: 'Activity, duration (min), and calories are required' });
    if (typeof activity !== 'string' || !activity.trim()) return res.status(400).json({ message: 'Invalid activity' });
    if (isNaN(Number(duration_min)) || Number(duration_min) <= 0) return res.status(400).json({ message: 'Duration must be positive number' });
    if (isNaN(Number(calories)) || Number(calories) < 0) return res.status(400).json({ message: 'Calories must be non-negative number' });
    
    if (USE_SQLITE) {
      const r = await dbQuery(
        `INSERT INTO activities (email, activity, duration_min, calories, intensity, type, entry_date)
         VALUES ($1,$2,$3,$4,$5,$6,$7)`,
        [req.user.email, activity.trim(), Number(duration_min), Number(calories), intensity || null, type || null, getTodayUTC()]
      );
      const inserted = await dbQuery('SELECT * FROM activities WHERE id=$1', [r.lastID]);
      res.status(201).json(inserted.rows[0]);
    } else {
      const r = await dbQuery(
        `INSERT INTO activities (email, activity, duration_min, calories, intensity, type, entry_date)
         VALUES ($1,$2,$3,$4,$5,$6,(now() AT TIME ZONE 'utc')::date)
         RETURNING *`,
        [req.user.email, activity.trim(), Number(duration_min), Number(calories), intensity || null, type || null]
      );
      r.rows[0].entry_date = toUTCDateString(r.rows[0].entry_date);
      res.status(201).json(r.rows[0]);
    }
  } catch (err) {
    res.status(500).json({ message: 'Error logging activity', error: err.message });
  }
});

app.put('/api/activities/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const { activity, duration_min, calories, intensity, type } = req.body;
    if (!activity || duration_min == null || calories == null)
      return res.status(400).json({ message: 'Activity, duration, and calories are required' });
    const r = await dbQuery(
      `UPDATE activities SET activity=$1, duration_min=$2, calories=$3, intensity=$4, type=$5 
       WHERE id=$6 AND email=$7 RETURNING *`,
      [activity.trim(), Number(duration_min), Number(calories), intensity || null, type || null, id, req.user.email]
    );
    if (r.rowCount === 0) return res.status(404).json({ message: 'Activity not found' });
    r.rows[0].entry_date = toUTCDateString(r.rows[0].entry_date);
    res.json(r.rows[0]);
  } catch (err) {
    res.status(500).json({ message: 'Error updating activity', error: err.message });
  }
});

app.delete('/api/activities/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const r = await dbQuery('DELETE FROM activities WHERE id=$1 AND email=$2 RETURNING *', [id, req.user.email]);
    if (r.rowCount === 0) return res.status(404).json({ message: 'Activity not found' });
    res.json({ message: 'Activity deleted', activity: r.rows[0] });
  } catch (err) {
    res.status(500).json({ message: 'Error deleting activity', error: err.message });
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
    const { name, calories, protein, sugar, carbs, fat, mealType } = req.body;
    if (!name || calories == null || protein == null || sugar == null)
      return res.status(400).json({ message: 'Name, calories, protein, and sugar are required' });
    if (typeof name !== 'string' || !name.trim()) return res.status(400).json({ message: 'Invalid food name' });
    if ([calories, protein, sugar].some(v => isNaN(Number(v)))) return res.status(400).json({ message: 'Calories, protein, and sugar must be numbers' });
    
    if (USE_SQLITE) {
      const r = await dbQuery(
        `INSERT INTO food (email, name, calories, protein, sugar, carbs, fat, meal_type, entry_date)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
        [req.user.email, name.trim(), Number(calories), Number(protein), Number(sugar), carbs ? Number(carbs) : null, fat ? Number(fat) : null, mealType || null, getTodayUTC()]
      );
      const inserted = await dbQuery('SELECT * FROM food WHERE id=$1', [r.lastID]);
      res.status(201).json(inserted.rows[0]);
    } else {
      const r = await dbQuery(
        `INSERT INTO food (email, name, calories, protein, sugar, carbs, fat, meal_type, entry_date)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,(now() AT TIME ZONE 'utc')::date)
         RETURNING *`,
        [req.user.email, name.trim(), Number(calories), Number(protein), Number(sugar), carbs ? Number(carbs) : null, fat ? Number(fat) : null, mealType || null]
      );
      r.rows[0].entry_date = toUTCDateString(r.rows[0].entry_date);
      res.status(201).json(r.rows[0]);
    }
  } catch (err) {
    res.status(500).json({ message: 'Error logging food', error: err.message });
  }
});

app.put('/api/food/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const { name, calories, protein, sugar, carbs, fat, mealType } = req.body;
    if (!name || calories == null || protein == null || sugar == null)
      return res.status(400).json({ message: 'Name, calories, protein, and sugar are required' });
    const r = await dbQuery(
      `UPDATE food SET name=$1, calories=$2, protein=$3, sugar=$4, carbs=$5, fat=$6, meal_type=$7 
       WHERE id=$8 AND email=$9 RETURNING *`,
      [name.trim(), Number(calories), Number(protein), Number(sugar), carbs ? Number(carbs) : null, fat ? Number(fat) : null, mealType || null, id, req.user.email]
    );
    if (r.rowCount === 0) return res.status(404).json({ message: 'Food entry not found' });
    r.rows[0].entry_date = toUTCDateString(r.rows[0].entry_date);
    res.json(r.rows[0]);
  } catch (err) {
    res.status(500).json({ message: 'Error updating food', error: err.message });
  }
});

app.delete('/api/food/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const r = await dbQuery('DELETE FROM food WHERE id=$1 AND email=$2 RETURNING *', [id, req.user.email]);
    if (r.rowCount === 0) return res.status(404).json({ message: 'Food entry not found' });
    res.json({ message: 'Food entry deleted', food: r.rows[0] });
  } catch (err) {
    res.status(500).json({ message: 'Error deleting food', error: err.message });
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
    const { hours, quality, bedtime, wakeTime } = req.body;
    if (hours == null || !quality)
      return res.status(400).json({ message: 'Hours and quality are required' });
    if (isNaN(Number(hours)) || Number(hours) < 0) return res.status(400).json({ message: 'Hours must be a non-negative number' });
    if (typeof quality !== 'string' || !quality.trim()) return res.status(400).json({ message: 'Quality must be a non-empty string' });
    
    if (USE_SQLITE) {
      const r = await dbQuery(
        `INSERT INTO sleep (email, hours, quality, bedtime, wake_time, entry_date)
         VALUES ($1,$2,$3,$4,$5,$6)`,
        [req.user.email, Number(hours), quality.trim(), bedtime || null, wakeTime || null, getTodayUTC()]
      );
      const inserted = await dbQuery('SELECT * FROM sleep WHERE id=$1', [r.lastID]);
      res.status(201).json(inserted.rows[0]);
    } else {
      const r = await dbQuery(
        `INSERT INTO sleep (email, hours, quality, bedtime, wake_time, entry_date)
         VALUES ($1,$2,$3,$4,$5,(now() AT TIME ZONE 'utc')::date)
         RETURNING *`,
        [req.user.email, Number(hours), quality.trim(), bedtime || null, wakeTime || null]
      );
      r.rows[0].entry_date = toUTCDateString(r.rows[0].entry_date);
      res.status(201).json(r.rows[0]);
    }
  } catch (err) {
    res.status(500).json({ message: 'Error logging sleep', error: err.message });
  }
});

app.put('/api/sleep/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const { hours, quality, bedtime, wakeTime } = req.body;
    if (hours == null || !quality)
      return res.status(400).json({ message: 'Hours and quality are required' });
    const r = await dbQuery(
      `UPDATE sleep SET hours=$1, quality=$2, bedtime=$3, wake_time=$4 
       WHERE id=$5 AND email=$6 RETURNING *`,
      [Number(hours), quality.trim(), bedtime || null, wakeTime || null, id, req.user.email]
    );
    if (r.rowCount === 0) return res.status(404).json({ message: 'Sleep entry not found' });
    r.rows[0].entry_date = toUTCDateString(r.rows[0].entry_date);
    res.json(r.rows[0]);
  } catch (err) {
    res.status(500).json({ message: 'Error updating sleep', error: err.message });
  }
});

app.delete('/api/sleep/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const r = await dbQuery('DELETE FROM sleep WHERE id=$1 AND email=$2 RETURNING *', [id, req.user.email]);
    if (r.rowCount === 0) return res.status(404).json({ message: 'Sleep entry not found' });
    res.json({ message: 'Sleep entry deleted', sleep: r.rows[0] });
  } catch (err) {
    res.status(500).json({ message: 'Error deleting sleep', error: err.message });
  }
});

// ---------- Recent Logs Endpoint ----------
app.get('/api/recent', authenticate, async (req, res) => {
  try {
    const email = req.user.email;
    // Get all logs for today for each type, with a source field
    const [activities, food, sleep] = await Promise.all([
      dbQuery(
        `SELECT id, activity, duration_min, calories, entry_date, created_at, 'activity' as type
         FROM activities
         WHERE email=$1 AND entry_date=(now() AT TIME ZONE 'utc')::date
         ORDER BY id DESC`,
        [email]
      ),
      dbQuery(
        `SELECT id, name, calories, entry_date, created_at, 'food' as type
         FROM food
         WHERE email=$1 AND entry_date=(now() AT TIME ZONE 'utc')::date
         ORDER BY id DESC`,
        [email]
      ),
      dbQuery(
        `SELECT id, hours, quality, entry_date, created_at, 'sleep' as type
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

// ---------- Goals ----------
app.get('/api/goals', authenticate, async (req, res) => {
  try {
    const r = await dbQuery('SELECT * FROM goals WHERE email=$1', [req.user.email]);
    res.json(r.rows[0] || {});
  } catch (err) {
    res.status(500).json({ message: 'Error fetching goals', error: err.message });
  }
});

app.post('/api/goals', authenticate, async (req, res) => {
  try {
    const { dailyCalories, weeklyWorkouts, dailySteps, weeklyWeight, sleepHours, waterIntake } = req.body;
    const r = await dbQuery(
      `INSERT INTO goals (email, daily_calories, weekly_workouts, daily_steps, weekly_weight, sleep_hours, water_intake, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,now())
       ON CONFLICT (email) DO UPDATE SET
         daily_calories=$2, weekly_workouts=$3, daily_steps=$4, weekly_weight=$5, sleep_hours=$6, water_intake=$7, updated_at=now()
       RETURNING *`,
      [req.user.email, dailyCalories || null, weeklyWorkouts || null, dailySteps || null, weeklyWeight || null, sleepHours || null, waterIntake || null]
    );
    res.json({ message: 'Goals saved successfully', goals: r.rows[0] });
  } catch (err) {
    res.status(500).json({ message: 'Error saving goals', error: err.message });
  }
});

// ---------- Workouts ----------
app.get('/api/workouts', authenticate, async (req, res) => {
  try {
    const r = await dbQuery('SELECT * FROM workouts WHERE email=$1 ORDER BY id DESC', [req.user.email]);
    res.json(r.rows);
  } catch (err) {
    res.status(500).json({ message: 'Error fetching workouts', error: err.message });
  }
});

app.post('/api/workouts', authenticate, async (req, res) => {
  try {
    const { name, exercises } = req.body;
    if (!name) return res.status(400).json({ message: 'Workout name is required' });
    const r = await dbQuery(
      `INSERT INTO workouts (email, name, exercises) VALUES ($1,$2,$3) RETURNING *`,
      [req.user.email, name.trim(), JSON.stringify(exercises || [])]
    );
    res.status(201).json(r.rows[0]);
  } catch (err) {
    res.status(500).json({ message: 'Error creating workout', error: err.message });
  }
});

app.put('/api/workouts/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const { name, exercises } = req.body;
    if (!name) return res.status(400).json({ message: 'Workout name is required' });
    const r = await dbQuery(
      `UPDATE workouts SET name=$1, exercises=$2, updated_at=now() WHERE id=$3 AND email=$4 RETURNING *`,
      [name.trim(), JSON.stringify(exercises || []), id, req.user.email]
    );
    if (r.rowCount === 0) return res.status(404).json({ message: 'Workout not found' });
    res.json(r.rows[0]);
  } catch (err) {
    res.status(500).json({ message: 'Error updating workout', error: err.message });
  }
});

app.delete('/api/workouts/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const r = await dbQuery('DELETE FROM workouts WHERE id=$1 AND email=$2 RETURNING *', [id, req.user.email]);
    if (r.rowCount === 0) return res.status(404).json({ message: 'Workout not found' });
    res.json({ message: 'Workout deleted', workout: r.rows[0] });
  } catch (err) {
    res.status(500).json({ message: 'Error deleting workout', error: err.message });
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