// backend/index-local.js - SQLite Local Development Version
// Run with: node index-local.js
// No MongoDB or external dependencies required!

const express = require('express');
const cors = require('cors');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const sqlite3 = require('sqlite3').verbose();

const app = express();
const SECRET = process.env.JWT_SECRET || 'local-dev-secret-change-in-production';
const ADMIN_EMAIL = (process.env.ADMIN_EMAIL || '').toLowerCase();

// ---------- SQLite Database Setup ----------
console.log('🔵 Starting Exerly Fitness (Local SQLite Mode)');
const db = new sqlite3.Database('./fitness-local.db', (err) => {
  if (err) console.error('SQLite connection error:', err);
  else console.log('✅ Connected to SQLite database: fitness-local.db');
});

// Promisify database operations
function dbQuery(query, params = []) {
  return new Promise((resolve, reject) => {
    const sqliteQuery = query.replace(/\$\d+/g, '?');
    
    if (sqliteQuery.trim().toUpperCase().startsWith('SELECT') || 
        sqliteQuery.trim().toUpperCase().includes('RETURNING')) {
      db.all(sqliteQuery.replace(/RETURNING \*/gi, ''), params, (err, rows) => {
        if (err) reject(err);
        else resolve({ rows: rows || [], rowCount: rows?.length || 0 });
      });
    } else {
      db.run(sqliteQuery, params, function(err) {
        if (err) reject(err);
        else resolve({ rows: [], rowCount: this.changes, lastID: this.lastID });
      });
    }
  });
}

// Get inserted row helper
async function getLastInserted(table, lastID) {
  const r = await dbQuery(`SELECT * FROM ${table} WHERE id = ?`, [lastID]);
  return r.rows[0];
}

// ---------- Database Initialization ----------
async function initDb() {
  await dbQuery(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL,
      hash TEXT NOT NULL,
      profile TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      is_admin INTEGER DEFAULT 0,
      onboardingCompleted INTEGER DEFAULT 0,
      age INTEGER,
      gender TEXT,
      height REAL,
      weight REAL,
      goal TEXT,
      experienceLevel TEXT,
      workoutDaysPerWeek INTEGER DEFAULT 3,
      equipmentAccess TEXT,
      aiCreditsRemaining INTEGER DEFAULT 5,
      aiDailyCreditsUsed INTEGER DEFAULT 0,
      aiLastCreditReset TEXT DEFAULT CURRENT_TIMESTAMP,
      aiDailyResetDate TEXT DEFAULT CURRENT_TIMESTAMP
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

  await dbQuery(`
    CREATE TABLE IF NOT EXISTS ai_plans (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT NOT NULL,
      type TEXT NOT NULL,
      prompt TEXT NOT NULL,
      response TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      applied INTEGER DEFAULT 0
    );
  `);

  // Create indexes
  await dbQuery(`CREATE INDEX IF NOT EXISTS idx_activities_email_date ON activities(email, entry_date);`);
  await dbQuery(`CREATE INDEX IF NOT EXISTS idx_food_email_date ON food(email, entry_date);`);
  await dbQuery(`CREATE INDEX IF NOT EXISTS idx_sleep_email_date ON sleep(email, entry_date);`);
  await dbQuery(`CREATE INDEX IF NOT EXISTS idx_workouts_email ON workouts(email);`);

  console.log('✅ Database tables ready');
}

// ---------- Helper Functions ----------
function calculateMaintenance(profile) {
  if (!profile) return null;
  const { age, sex, height_cm, weight_kg, activity_level } = profile;
  if (!age || !height_cm || !weight_kg) return null;
  const s = sex === 'male' ? 5 : -161;
  const bmr = 10 * Number(weight_kg) + 6.25 * Number(height_cm) - 5 * Number(age) + s;
  const multiplier = {
    sedentary: 1.2, light: 1.375, moderate: 1.55, active: 1.725, 'very active': 1.9
  }[activity_level] || 1.2;
  return Math.round(bmr * multiplier);
}

function validateEmail(email) {
  return typeof email === 'string' && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function getTodayUTC() {
  return new Date().toISOString().slice(0, 10);
}

function decodeProfile(profile) {
  if (typeof profile === 'string') {
    try { return JSON.parse(profile); } catch { return null; }
  }
  return profile;
}

function encodeProfile(profile) {
  return JSON.stringify(profile);
}

function serializeMobileUser(user) {
  if (!user) return null;
  const profile = decodeProfile(user.profile) || {};
  const remainingCredits = user.aiCreditsRemaining ?? null;

  return {
    _id: user.id != null ? String(user.id) : undefined,
    email: user.email,
    name: user.name ?? null,
    isAdmin: !!user.is_admin,
    onboardingCompleted: !!user.onboardingCompleted,
    age: user.age ?? profile.age ?? null,
    gender: user.gender ?? profile.gender ?? profile.sex ?? null,
    height: user.height ?? profile.height ?? profile.height_cm ?? null,
    weight: user.weight ?? profile.weight ?? profile.weight_kg ?? null,
    activityLevel: profile.activityLevel ?? profile.activity_level ?? null,
    goal: user.goal ?? profile.goal ?? null,
    targetWeight: profile.targetWeight ?? profile.target_weight ?? null,
    aiCreditsRemaining: remainingCredits,
    dailyAiCreditsUsed: user.aiDailyCreditsUsed ?? 0,
    hourlyAiCreditsUsed: remainingCredits == null ? null : Math.max(0, 5 - Number(remainingCredits))
  };
}

function buildOnboardingProfile(existingProfile, payload) {
  const profile = decodeProfile(existingProfile) || {};
  const height = Number(payload.height);
  const weight = Number(payload.weight);
  const targetWeight = payload.targetWeight != null ? Number(payload.targetWeight) : null;
  const activityLevel = payload.activityLevel || payload.activity_level || profile.activityLevel || profile.activity_level || null;

  return {
    ...profile,
    age: parseInt(payload.age, 10),
    gender: payload.gender,
    sex: payload.gender,
    height,
    height_cm: height,
    weight,
    weight_kg: weight,
    activityLevel,
    activity_level: activityLevel,
    goal: payload.goal,
    targetWeight: targetWeight ?? profile.targetWeight ?? null,
    target_weight: targetWeight ?? profile.target_weight ?? null
  };
}

// ---------- CORS Setup (Allow Mobile) ----------
const allowedOrigins = [
  'http://localhost:3000',
  'http://127.0.0.1:3000',
  'http://localhost:5173',
  'http://127.0.0.1:5173',
  'http://localhost:8081',
  'http://localhost:8082',
  'http://localhost:8083',
  'http://localhost:19000',
  'http://localhost:19006',
  'https://exerlyfitness.com',
  'https://www.exerlyfitness.com',
];

app.use(cors({
  origin: function (origin, callback) {
    if (!origin) return callback(null, true);
    
    // Check string origins
    if (allowedOrigins.includes(origin)) {
      return callback(null, true);
    }
    
    // Allow local network IPs (for mobile)
    if (/^http:\/\/(192\.168|10\.|172\.(1[6-9]|2[0-9]|3[0-1]))\.\d{1,3}\.\d{1,3}(:\d+)?$/.test(origin)) {
      return callback(null, true);
    }
    
    return callback(null, false);
  },
  credentials: true,
  optionsSuccessStatus: 204,
}));

app.use(express.json());

// ---------- Health Check ----------
app.get('/ping', (_req, res) => res.send('pong'));

app.get('/api/health', async (_req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    database: { status: 'connected', type: 'SQLite (Local)' },
    memory: {
      used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024) + ' MB',
      total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024) + ' MB'
    },
    mode: 'LOCAL DEVELOPMENT',
    version: '1.0.0-local'
  });
});

// ---------- Auth ----------
app.post('/signup', async (req, res) => {
  try {
    let { name, email, password } = req.body;
    if (!name || !email || !password)
      return res.status(400).json({ message: 'Name, email & password required' });
    if (!validateEmail(email)) return res.status(400).json({ message: 'Invalid email format' });
    email = email.toLowerCase();
    
    const existing = await dbQuery('SELECT 1 FROM users WHERE email=?', [email]);
    if (existing.rowCount > 0) return res.status(409).json({ message: 'User with this email already exists' });
    
    const hash = await bcrypt.hash(password, 10);
    const makeAdmin = ADMIN_EMAIL && email === ADMIN_EMAIL;
    
    await dbQuery('INSERT INTO users (name, email, hash, is_admin) VALUES (?,?,?,?)', [name, email, hash, makeAdmin ? 1 : 0]);
    const createdUser = await dbQuery('SELECT * FROM users WHERE email=?', [email]);
    const token = jwt.sign({ email, name, is_admin: !!makeAdmin }, SECRET, { expiresIn: '12h' });
    res.json({ message: 'Signup successful', token, user: serializeMobileUser(createdUser.rows[0]) });
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
    
    const r = await dbQuery('SELECT * FROM users WHERE email=?', [email]);
    const user = r.rows[0];
    if (!user) return res.status(401).json({ message: 'Invalid credentials' });
    
    const ok = await bcrypt.compare(password, user.hash);
    if (!ok) return res.status(401).json({ message: 'Invalid credentials' });
    
    const token = jwt.sign({ email: user.email, name: user.name, is_admin: !!user.is_admin }, SECRET, { expiresIn: '12h' });
    res.json({ token, user: serializeMobileUser(user) });
  } catch (err) {
    res.status(500).json({ message: 'Login failed', error: err.message });
  }
});

// ---------- Auth Middleware ----------
function authenticate(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth) return res.status(401).json({ message: 'Authorization header missing' });
  const parts = auth.split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer') {
    return res.status(401).json({ message: 'Invalid authorization format' });
  }
  try {
    req.user = jwt.verify(parts[1], SECRET);
    next();
  } catch {
    res.status(401).json({ message: 'Invalid or expired token' });
  }
}

function requireAdmin(req, res, next) {
  if (!req.user?.is_admin) return res.status(403).json({ message: 'Admin only' });
  next();
}

// ---------- Profile ----------
app.get('/api/profile', authenticate, async (req, res) => {
  try {
    const r = await dbQuery('SELECT profile FROM users WHERE email=?', [req.user.email]);
    res.json(decodeProfile(r.rows[0]?.profile) || {});
  } catch (err) {
    res.status(500).json({ message: 'Error fetching profile', error: err.message });
  }
});

app.get('/api/me', authenticate, async (req, res) => {
  try {
    const r = await dbQuery('SELECT * FROM users WHERE email=?', [req.user.email]);
    if (!r.rows[0]) return res.status(404).json({ message: 'User not found' });
    res.json(serializeMobileUser(r.rows[0]));
  } catch (err) {
    res.status(500).json({ message: 'Error fetching current user', error: err.message });
  }
});

app.post('/api/profile', authenticate, async (req, res) => {
  try {
    const profile = req.body || {};
    await dbQuery('UPDATE users SET profile=? WHERE email=?', [encodeProfile(profile), req.user.email]);
    res.json({ message: 'Profile saved', profile });
  } catch (err) {
    res.status(500).json({ message: 'Error saving profile', error: err.message });
  }
});

app.put('/api/profile', authenticate, async (req, res) => {
  try {
    const profile = req.body || {};
    await dbQuery('UPDATE users SET profile=? WHERE email=?', [encodeProfile(profile), req.user.email]);
    res.json({ message: 'Profile saved', profile });
  } catch (err) {
    res.status(500).json({ message: 'Error saving profile', error: err.message });
  }
});

// ---------- Onboarding ----------
app.post('/api/user/onboarding', authenticate, async (req, res) => {
  try {
    const {
      age, gender, height, weight, goal,
      activityLevel, targetWeight,
      experienceLevel, workoutDaysPerWeek, equipmentAccess
    } = req.body;
    
    if (!age || !gender || !height || !weight || !goal) {
      return res.status(400).json({ message: 'All fields are required' });
    }

    const existingUserResult = await dbQuery('SELECT * FROM users WHERE email=?', [req.user.email]);
    const existingUser = existingUserResult.rows[0];
    const mergedProfile = buildOnboardingProfile(existingUser?.profile, req.body);
    
    await dbQuery(`
      UPDATE users SET 
        onboardingCompleted=1, age=?, gender=?, height=?, weight=?, 
        goal=?, experienceLevel=?, workoutDaysPerWeek=?, equipmentAccess=?, profile=?
      WHERE email=?
    `, [
      parseInt(age), gender, Number(height), Number(weight), goal,
      experienceLevel || existingUser?.experienceLevel || 'beginner',
      parseInt(workoutDaysPerWeek) || 3,
      equipmentAccess || existingUser?.equipmentAccess || 'full_gym',
      encodeProfile(mergedProfile),
      req.user.email
    ]);

    const updatedUser = await dbQuery('SELECT * FROM users WHERE email=?', [req.user.email]);
    
    res.json({
      message: 'Onboarding completed successfully!',
      maintenance: calculateMaintenance(mergedProfile),
      user: serializeMobileUser(updatedUser.rows[0])
    });
  } catch (err) {
    res.status(500).json({ message: 'Error completing onboarding', error: err.message });
  }
});

// ---------- Activities ----------
app.get('/api/activities', authenticate, async (req, res) => {
  try {
    const r = await dbQuery('SELECT * FROM activities WHERE email=? ORDER BY id DESC', [req.user.email]);
    res.json(r.rows);
  } catch (err) {
    res.status(500).json({ message: 'Error fetching activities', error: err.message });
  }
});

app.post('/api/activities', authenticate, async (req, res) => {
  try {
    const { activity, duration_min, calories, intensity, type } = req.body;
    if (!activity || duration_min == null || calories == null)
      return res.status(400).json({ message: 'Activity, duration, and calories are required' });
    
    const result = await dbQuery(
      `INSERT INTO activities (email, activity, duration_min, calories, intensity, type, entry_date) VALUES (?,?,?,?,?,?,?)`,
      [req.user.email, activity.trim(), Number(duration_min), Number(calories), intensity || null, type || null, getTodayUTC()]
    );
    const inserted = await getLastInserted('activities', result.lastID);
    res.status(201).json(inserted);
  } catch (err) {
    res.status(500).json({ message: 'Error logging activity', error: err.message });
  }
});

app.put('/api/activities/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const { activity, duration_min, calories, intensity, type } = req.body;
    await dbQuery(
      `UPDATE activities SET activity=?, duration_min=?, calories=?, intensity=?, type=? WHERE id=? AND email=?`,
      [activity.trim(), Number(duration_min), Number(calories), intensity, type, id, req.user.email]
    );
    const updated = await dbQuery('SELECT * FROM activities WHERE id=?', [id]);
    res.json(updated.rows[0]);
  } catch (err) {
    res.status(500).json({ message: 'Error updating activity', error: err.message });
  }
});

app.delete('/api/activities/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    await dbQuery('DELETE FROM activities WHERE id=? AND email=?', [id, req.user.email]);
    res.json({ message: 'Activity deleted' });
  } catch (err) {
    res.status(500).json({ message: 'Error deleting activity', error: err.message });
  }
});

// ---------- Food ----------
app.get('/api/food', authenticate, async (req, res) => {
  try {
    const r = await dbQuery('SELECT * FROM food WHERE email=? ORDER BY id DESC', [req.user.email]);
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
    
    const result = await dbQuery(
      `INSERT INTO food (email, name, calories, protein, sugar, carbs, fat, meal_type, entry_date) VALUES (?,?,?,?,?,?,?,?,?)`,
      [req.user.email, name.trim(), Number(calories), Number(protein), Number(sugar), carbs ? Number(carbs) : null, fat ? Number(fat) : null, mealType || null, getTodayUTC()]
    );
    const inserted = await getLastInserted('food', result.lastID);
    res.status(201).json(inserted);
  } catch (err) {
    res.status(500).json({ message: 'Error logging food', error: err.message });
  }
});

app.put('/api/food/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const { name, calories, protein, sugar, carbs, fat, mealType } = req.body;
    await dbQuery(
      `UPDATE food SET name=?, calories=?, protein=?, sugar=?, carbs=?, fat=?, meal_type=? WHERE id=? AND email=?`,
      [name.trim(), Number(calories), Number(protein), Number(sugar), carbs, fat, mealType, id, req.user.email]
    );
    const updated = await dbQuery('SELECT * FROM food WHERE id=?', [id]);
    res.json(updated.rows[0]);
  } catch (err) {
    res.status(500).json({ message: 'Error updating food', error: err.message });
  }
});

app.delete('/api/food/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    await dbQuery('DELETE FROM food WHERE id=? AND email=?', [id, req.user.email]);
    res.json({ message: 'Food entry deleted' });
  } catch (err) {
    res.status(500).json({ message: 'Error deleting food', error: err.message });
  }
});

// ---------- Sleep ----------
app.get('/api/sleep', authenticate, async (req, res) => {
  try {
    const r = await dbQuery('SELECT * FROM sleep WHERE email=? ORDER BY id DESC', [req.user.email]);
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
    
    const result = await dbQuery(
      `INSERT INTO sleep (email, hours, quality, bedtime, wake_time, entry_date) VALUES (?,?,?,?,?,?)`,
      [req.user.email, Number(hours), quality.trim(), bedtime || null, wakeTime || null, getTodayUTC()]
    );
    const inserted = await getLastInserted('sleep', result.lastID);
    res.status(201).json(inserted);
  } catch (err) {
    res.status(500).json({ message: 'Error logging sleep', error: err.message });
  }
});

app.put('/api/sleep/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const { hours, quality, bedtime, wakeTime } = req.body;
    await dbQuery(
      `UPDATE sleep SET hours=?, quality=?, bedtime=?, wake_time=? WHERE id=? AND email=?`,
      [Number(hours), quality.trim(), bedtime, wakeTime, id, req.user.email]
    );
    const updated = await dbQuery('SELECT * FROM sleep WHERE id=?', [id]);
    res.json(updated.rows[0]);
  } catch (err) {
    res.status(500).json({ message: 'Error updating sleep', error: err.message });
  }
});

app.delete('/api/sleep/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    await dbQuery('DELETE FROM sleep WHERE id=? AND email=?', [id, req.user.email]);
    res.json({ message: 'Sleep entry deleted' });
  } catch (err) {
    res.status(500).json({ message: 'Error deleting sleep', error: err.message });
  }
});

// ---------- Goals ----------
app.get('/api/goals', authenticate, async (req, res) => {
  try {
    const r = await dbQuery('SELECT * FROM goals WHERE email=?', [req.user.email]);
    res.json(r.rows[0] || {});
  } catch (err) {
    res.status(500).json({ message: 'Error fetching goals', error: err.message });
  }
});

app.post('/api/goals', authenticate, async (req, res) => {
  try {
    const { dailyCalories, weeklyWorkouts, dailySteps, weeklyWeight, sleepHours, waterIntake } = req.body;
    
    // Check if exists
    const existing = await dbQuery('SELECT id FROM goals WHERE email=?', [req.user.email]);
    if (existing.rowCount > 0) {
      await dbQuery(
        `UPDATE goals SET daily_calories=?, weekly_workouts=?, daily_steps=?, weekly_weight=?, sleep_hours=?, water_intake=?, updated_at=CURRENT_TIMESTAMP WHERE email=?`,
        [dailyCalories, weeklyWorkouts, dailySteps, weeklyWeight, sleepHours, waterIntake, req.user.email]
      );
    } else {
      await dbQuery(
        `INSERT INTO goals (email, daily_calories, weekly_workouts, daily_steps, weekly_weight, sleep_hours, water_intake) VALUES (?,?,?,?,?,?,?)`,
        [req.user.email, dailyCalories, weeklyWorkouts, dailySteps, weeklyWeight, sleepHours, waterIntake]
      );
    }
    
    const goals = await dbQuery('SELECT * FROM goals WHERE email=?', [req.user.email]);
    res.json({ message: 'Goals saved', goals: goals.rows[0] });
  } catch (err) {
    res.status(500).json({ message: 'Error saving goals', error: err.message });
  }
});

// ---------- Workouts ----------
app.get('/api/workouts', authenticate, async (req, res) => {
  try {
    const r = await dbQuery('SELECT * FROM workouts WHERE email=? ORDER BY id DESC', [req.user.email]);
    res.json(r.rows.map(w => ({ ...w, exercises: w.exercises ? JSON.parse(w.exercises) : [] })));
  } catch (err) {
    res.status(500).json({ message: 'Error fetching workouts', error: err.message });
  }
});

app.post('/api/workouts', authenticate, async (req, res) => {
  try {
    const { name, exercises } = req.body;
    if (!name) return res.status(400).json({ message: 'Workout name is required' });
    
    const result = await dbQuery(
      `INSERT INTO workouts (email, name, exercises) VALUES (?,?,?)`,
      [req.user.email, name.trim(), JSON.stringify(exercises || [])]
    );
    const inserted = await getLastInserted('workouts', result.lastID);
    res.status(201).json({ ...inserted, exercises: JSON.parse(inserted.exercises || '[]') });
  } catch (err) {
    res.status(500).json({ message: 'Error creating workout', error: err.message });
  }
});

app.put('/api/workouts/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const { name, exercises } = req.body;
    await dbQuery(
      `UPDATE workouts SET name=?, exercises=?, updated_at=CURRENT_TIMESTAMP WHERE id=? AND email=?`,
      [name.trim(), JSON.stringify(exercises || []), id, req.user.email]
    );
    const updated = await dbQuery('SELECT * FROM workouts WHERE id=?', [id]);
    res.json({ ...updated.rows[0], exercises: JSON.parse(updated.rows[0].exercises || '[]') });
  } catch (err) {
    res.status(500).json({ message: 'Error updating workout', error: err.message });
  }
});

app.delete('/api/workouts/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    await dbQuery('DELETE FROM workouts WHERE id=? AND email=?', [id, req.user.email]);
    res.json({ message: 'Workout deleted' });
  } catch (err) {
    res.status(500).json({ message: 'Error deleting workout', error: err.message });
  }
});

// ---------- Dashboard Data ----------
app.get('/api/dashboard-data', authenticate, async (req, res) => {
  try {
    const email = req.user.email;
    const today = getTodayUTC();
    
    const [activities, food, sleep, user] = await Promise.all([
      dbQuery('SELECT calories FROM activities WHERE email=? AND entry_date=?', [email, today]),
      dbQuery('SELECT calories FROM food WHERE email=? AND entry_date=?', [email, today]),
      dbQuery('SELECT hours FROM sleep WHERE email=? AND entry_date=?', [email, today]),
      dbQuery('SELECT profile FROM users WHERE email=?', [email]),
    ]);
    
    const totalBurned = activities.rows.reduce((sum, r) => sum + Number(r.calories), 0);
    const workoutCount = activities.rowCount;
    const totalConsumed = food.rows.reduce((sum, r) => sum + Number(r.calories), 0);
    const totalSleepHours = sleep.rows.reduce((sum, r) => sum + Number(r.hours), 0);
    const maintenance = calculateMaintenance(decodeProfile(user.rows[0]?.profile));
    
    const cards = [
      { label: 'Total Workouts', value: workoutCount, route: '/dashboard/activities' },
      { label: 'Calories Burned', value: `${totalBurned} kcal`, route: '/dashboard/activities' },
      { label: 'Calories Consumed', value: `${totalConsumed} kcal`, route: '/dashboard/food' },
      { label: 'Sleep (hrs)', value: `${totalSleepHours}`, route: '/dashboard/sleep' },
    ];
    
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

// ---------- Recent Logs ----------
app.get('/api/recent', authenticate, async (req, res) => {
  try {
    const email = req.user.email;
    const today = getTodayUTC();
    
    const [activities, food, sleep] = await Promise.all([
      dbQuery('SELECT *, "activity" as type FROM activities WHERE email=? AND entry_date=? ORDER BY id DESC', [email, today]),
      dbQuery('SELECT *, "food" as type FROM food WHERE email=? AND entry_date=? ORDER BY id DESC', [email, today]),
      dbQuery('SELECT *, "sleep" as type FROM sleep WHERE email=? AND entry_date=? ORDER BY id DESC', [email, today]),
    ]);
    
    let logs = [...activities.rows, ...food.rows, ...sleep.rows];
    logs.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    res.json(logs);
  } catch (err) {
    res.status(500).json({ message: 'Error fetching recent logs', error: err.message });
  }
});

// ---------- Reset Today ----------
app.post('/api/reset-today', authenticate, async (req, res) => {
  try {
    const email = req.user.email;
    const today = getTodayUTC();
    
    await Promise.all([
      dbQuery('DELETE FROM activities WHERE email=? AND entry_date=?', [email, today]),
      dbQuery('DELETE FROM food WHERE email=? AND entry_date=?', [email, today]),
      dbQuery('DELETE FROM sleep WHERE email=? AND entry_date=?', [email, today]),
    ]);
    
    res.json({ message: "Today's logs deleted" });
  } catch (err) {
    res.status(500).json({ message: 'Error resetting today', error: err.message });
  }
});

// ---------- AI Credits (Mock) ----------
app.get('/api/ai/credits', authenticate, async (req, res) => {
  res.json({
    hourly: { remaining: 5, limit: 5, resetTime: '60:00' },
    daily: { used: 0, limit: 20, resetTime: '24h 0m' }
  });
});

// ---------- AI Plans (Mock) ----------
app.get('/api/ai/plans', authenticate, async (req, res) => {
  try {
    const r = await dbQuery('SELECT * FROM ai_plans WHERE email=? ORDER BY id DESC', [req.user.email]);
    res.json(r.rows);
  } catch (err) {
    res.status(500).json({ message: 'Error fetching AI plans', error: err.message });
  }
});

app.post('/api/ai/plans', authenticate, async (req, res) => {
  try {
    const { type, prompt, response } = req.body;
    const result = await dbQuery(
      'INSERT INTO ai_plans (email, type, prompt, response) VALUES (?,?,?,?)',
      [req.user.email, type || 'custom', prompt || '', response || 'Mock AI response - Local mode']
    );
    const inserted = await getLastInserted('ai_plans', result.lastID);
    res.status(201).json(inserted);
  } catch (err) {
    res.status(500).json({ message: 'Error saving AI plan', error: err.message });
  }
});

app.delete('/api/ai/plans/:id', authenticate, async (req, res) => {
  try {
    await dbQuery('DELETE FROM ai_plans WHERE id=? AND email=?', [req.params.id, req.user.email]);
    res.json({ message: 'AI plan deleted' });
  } catch (err) {
    res.status(500).json({ message: 'Error deleting AI plan', error: err.message });
  }
});

// ---------- AI Generate (Mock) ----------
app.post('/api/ai/generate', authenticate, async (req, res) => {
  const { type } = req.body;
  
  const mockResponses = {
    workout_plan: "🏋️ **Your Personalized Workout Plan**\n\n**Day 1 - Upper Body**\n- Bench Press: 3x10\n- Rows: 3x10\n- Shoulder Press: 3x8\n\n**Day 2 - Lower Body**\n- Squats: 4x8\n- Lunges: 3x10\n- Calf Raises: 3x15\n\n*Note: This is a mock response for local development*",
    nutrition_advice: "🥗 **Nutrition Recommendations**\n\n- Aim for 1g protein per lb of body weight\n- Eat plenty of vegetables\n- Stay hydrated with 8 glasses of water\n- Limit processed foods\n\n*Note: This is a mock response for local development*",
    progress_analysis: "📊 **Progress Analysis**\n\nYou're doing great! Keep up the consistent effort.\n\n- Workouts this week: Good consistency\n- Nutrition: On track\n- Sleep: Could improve\n\n*Note: This is a mock response for local development*",
    custom_question: "💡 **AI Coach Response**\n\nThank you for your question! In local development mode, AI responses are mocked.\n\nTo get real AI responses, connect to the production backend with MongoDB and Gemini API.\n\n*Note: This is a mock response for local development*"
  };
  
  res.json({
    success: true,
    response: mockResponses[type] || mockResponses.custom_question,
    creditsRemaining: { hourly: 5, daily: 0 }
  });
});

// ---------- Admin Routes ----------
app.get('/api/admin/users', authenticate, requireAdmin, async (_req, res) => {
  try {
    const r = await dbQuery('SELECT id, name, email, created_at, is_admin FROM users ORDER BY id DESC');
    res.json(r.rows);
  } catch (err) {
    res.status(500).json({ message: 'Error fetching users', error: err.message });
  }
});

// ---------- Start Server ----------
const PORT = process.env.PORT || 3001;
const HOST = '0.0.0.0';

initDb()
  .then(() => {
    app.listen(PORT, HOST, () => {
      console.log('');
      console.log('═══════════════════════════════════════════════════════════');
      console.log('  🏋️  EXERLY FITNESS - LOCAL DEVELOPMENT SERVER');
      console.log('═══════════════════════════════════════════════════════════');
      console.log(`  🟢 Server:    http://localhost:${PORT}`);
      console.log(`  📱 Mobile:    http://${require('os').networkInterfaces()['en0']?.[0]?.address || 'YOUR_IP'}:${PORT}`);
      console.log(`  💾 Database:  SQLite (fitness-local.db)`);
      console.log(`  🔧 Mode:      LOCAL DEVELOPMENT (No MongoDB required)`);
      console.log('═══════════════════════════════════════════════════════════');
      console.log('');
    });
  })
  .catch(err => {
    console.error('Failed to initialize database:', err);
    process.exit(1);
  });
