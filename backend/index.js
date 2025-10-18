// backend/index.js - MongoDB version
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');

const app = express();
const SECRET = process.env.JWT_SECRET || 'development-jwt-secret-change-in-production';
const ADMIN_EMAIL = (process.env.ADMIN_EMAIL || '').toLowerCase();

// MongoDB Connection String - from environment variable
const MONGODB_URI = process.env.MONGODB_URI;

if (!MONGODB_URI) {
  console.error('❌ ERROR: MONGODB_URI environment variable is required');
  console.error('   Please create a .env file with:');
  console.error('   MONGODB_URI=mongodb+srv://username:password@cluster...');
  process.exit(1);
}

// ---------- MongoDB Connection ----------
console.log('🔵 Connecting to MongoDB Atlas...');
console.log('🔍 Using connection string:', MONGODB_URI.replace(/\/\/.*@/, '//***:***@')); // Hide password in logs
mongoose.connect(MONGODB_URI)
  .then(() => console.log('✅ Connected to MongoDB Atlas'))
  .catch(err => {
    console.error('❌ MongoDB connection error:', err.message);
    console.error('\n💡 Troubleshooting:');
    console.error('   1. Verify your MongoDB Atlas password');
    console.error('   2. Check that your IP address is whitelisted in MongoDB Atlas');
    console.error('   3. Ensure the database user has proper permissions');
    console.error('   4. Get the correct connection string from MongoDB Atlas Dashboard\n');
    process.exit(1);
  });

// ---------- Mongoose Schemas ----------
const userSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true, lowercase: true },
  hash: { type: String, required: true },
  profile: { type: mongoose.Schema.Types.Mixed, default: {} },
  is_admin: { type: Boolean, default: false },
  created_at: { type: Date, default: Date.now },
  
  // Onboarding data
  onboardingCompleted: { type: Boolean, default: false },
  age: { type: Number },
  gender: { type: String },
  height: { type: Number }, // in cm
  weight: { type: Number }, // in kg
  goal: { type: String }, // lose_weight, build_muscle, improve_endurance, stay_healthy
  experienceLevel: { type: String }, // beginner, intermediate, advanced
  workoutDaysPerWeek: { type: Number, default: 3 },
  equipmentAccess: { type: String }, // full_gym, home_gym, no_equipment
  
  // AI Credit System
  aiCreditsRemaining: { type: Number, default: 5 }, // 0-5, resets hourly
  aiDailyCreditsUsed: { type: Number, default: 0 }, // 0-20, resets daily
  aiLastCreditReset: { type: Date, default: Date.now }, // Timestamp of last hourly reset
  aiDailyResetDate: { type: Date, default: Date.now } // Date of last daily reset
});

const activitySchema = new mongoose.Schema({
  email: { type: String, required: true, index: true },
  activity: { type: String, required: true },
  duration_min: { type: Number, required: true },
  calories: { type: Number, required: true },
  intensity: String,
  type: String,
  entry_date: { type: String, required: true, index: true },
  created_at: { type: Date, default: Date.now }
});

const aiPlanSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  type: { type: String, required: true }, // workout_plan, nutrition_advice, progress_analysis, custom_question
  prompt: { type: String, required: true },
  response: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
  applied: { type: Boolean, default: false },
  creditsUsedAtTime: {
    hourly: { type: Number },
    daily: { type: Number }
  }
});

const foodSchema = new mongoose.Schema({
  email: { type: String, required: true, index: true },
  name: { type: String, required: true },
  calories: { type: Number, required: true },
  protein: { type: Number, required: true },
  sugar: { type: Number, required: true },
  carbs: Number,
  fat: Number,
  meal_type: String,
  entry_date: { type: String, required: true, index: true },
  created_at: { type: Date, default: Date.now }
});

const sleepSchema = new mongoose.Schema({
  email: { type: String, required: true, index: true },
  hours: { type: Number, required: true },
  quality: { type: String, required: true },
  bedtime: String,
  wake_time: String,
  entry_date: { type: String, required: true, index: true },
  created_at: { type: Date, default: Date.now }
});

const goalsSchema = new mongoose.Schema({
  email: { type: String, required: true, unique: true },
  daily_calories: Number,
  weekly_workouts: Number,
  daily_steps: Number,
  weekly_weight: Number,
  sleep_hours: Number,
  water_intake: Number,
  updated_at: { type: Date, default: Date.now }
});

const workoutSchema = new mongoose.Schema({
  email: { type: String, required: true, index: true },
  name: { type: String, required: true },
  exercises: { type: mongoose.Schema.Types.Mixed, default: [] },
  created_at: { type: Date, default: Date.now },
  updated_at: { type: Date, default: Date.now }
});

// Create indexes
activitySchema.index({ email: 1, entry_date: 1 });
foodSchema.index({ email: 1, entry_date: 1 });
sleepSchema.index({ email: 1, entry_date: 1 });

// ---------- Models ----------
const User = mongoose.model('User', userSchema);
const Activity = mongoose.model('Activity', activitySchema);
const Food = mongoose.model('Food', foodSchema);
const Sleep = mongoose.model('Sleep', sleepSchema);
const Goals = mongoose.model('Goals', goalsSchema);
const Workout = mongoose.model('Workout', workoutSchema);
const AIPlan = mongoose.model('AIPlan', aiPlanSchema);

// ---------- Helper Functions ----------
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

function validateEmail(email) {
  return typeof email === 'string' && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function getTodayUTC() {
  return new Date().toISOString().slice(0, 10);
}

// ---------- AI Credit Management Functions ----------
function checkHourlyReset(user) {
  const now = new Date();
  const lastReset = new Date(user.aiLastCreditReset);
  const hoursSince = (now - lastReset) / (1000 * 60 * 60);
  
  if (hoursSince >= 1) {
    user.aiCreditsRemaining = 5;
    user.aiLastCreditReset = now;
    return true;
  }
  return false;
}

function checkDailyReset(user) {
  const now = new Date();
  const lastReset = new Date(user.aiDailyResetDate);
  
  if (now.toDateString() !== lastReset.toDateString()) {
    user.aiDailyCreditsUsed = 0;
    user.aiDailyResetDate = now;
    return true;
  }
  return false;
}

function getTimeUntilHourlyReset(user) {
  const now = new Date();
  const lastReset = new Date(user.aiLastCreditReset);
  const nextReset = new Date(lastReset.getTime() + 60 * 60 * 1000);
  const diff = nextReset - now;
  
  const minutes = Math.floor(diff / 60000);
  const seconds = Math.floor((diff % 60000) / 1000);
  
  return `${minutes}:${seconds.toString().padStart(2, '0')}`;
}

function getHoursUntilMidnight() {
  const now = new Date();
  const midnight = new Date(now);
  midnight.setHours(24, 0, 0, 0);
  
  const diff = midnight - now;
  const hours = Math.floor(diff / (1000 * 60 * 60));
  const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
  
  return `${hours}h ${minutes}m`;
}

// ---------- App Setup ----------
const allowedOrigins = [
  'http://localhost:3000',
  'http://127.0.0.1:3000',
  'http://localhost:5173',
  'http://127.0.0.1:5173',
  'https://whoisaldo.github.io',
];

app.use(cors({
  origin: function (origin, callback) {
    if (!origin) return callback(null, true);
    if (allowedOrigins.indexOf(origin) !== -1) {
      return callback(null, true);
    } else {
      return callback(null, false);
    }
  },
  credentials: true,
  optionsSuccessStatus: 204,
}));
app.use(express.json());

// Health check endpoints
app.get('/ping', (_req, res) => res.send('pong'));

app.get('/api/health', async (_req, res) => {
  try {
    const dbStatus = mongoose.connection.readyState === 1 ? 'connected' : 'disconnected';
    const healthStatus = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      database: {
        status: dbStatus,
        readyState: mongoose.connection.readyState,
        name: mongoose.connection.name
      },
      memory: {
        used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024) + ' MB',
        total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024) + ' MB'
      },
      version: '1.0.0'
    };
    
    res.status(200).json(healthStatus);
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error.message
    });
  }
});

// ---------- Auth ----------
app.post('/signup', async (req, res) => {
  try {
    let { name, email, password } = req.body;
    if (!name || !email || !password)
      return res.status(400).json({ message: 'Name, email & password required' });
    if (!validateEmail(email)) return res.status(400).json({ message: 'Invalid email format' });
    email = email.toLowerCase();
    
    const existing = await User.findOne({ email });
    if (existing) return res.status(409).json({ message: 'User with this email already exists' });
    
    const hash = await bcrypt.hash(password, 10);
    const makeAdmin = ADMIN_EMAIL && email === ADMIN_EMAIL;
    
    const user = await User.create({ name, email, hash, is_admin: !!makeAdmin });
    const token = jwt.sign({ email: user.email, name: user.name, is_admin: !!makeAdmin }, SECRET, { expiresIn: '12h' });
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
    
    const user = await User.findOne({ email });
    if (!user) return res.status(401).json({ message: 'Invalid credentials' });
    
    const ok = await bcrypt.compare(password, user.hash);
    if (!ok) return res.status(401).json({ message: 'Invalid credentials' });
    
    // Auto-promote admin
    if (ADMIN_EMAIL && email === ADMIN_EMAIL && !user.is_admin) {
      user.is_admin = true;
      await user.save();
    }
    
    const token = jwt.sign({ email: user.email, name: user.name, is_admin: !!user.is_admin }, SECRET, { expiresIn: '12h' });
    res.json({ token });
  } catch (err) {
    res.status(500).json({ message: 'Login failed', error: err.message });
  }
});

// ---------- Auth Middleware ----------
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
    const user = await User.findOne({ email: req.user.email });
    res.json(user?.profile || {});
  } catch (err) {
    res.status(500).json({ message: 'Error fetching profile', error: err.message });
  }
});

app.post('/api/profile', authenticate, async (req, res) => {
  try {
    const profile = req.body || {};
    await User.updateOne({ email: req.user.email }, { profile });
    res.json({ message: 'Profile saved', profile });
  } catch (err) {
    res.status(500).json({ message: 'Error saving profile', error: err.message });
  }
});

// ---------- Onboarding ----------
app.post('/api/user/onboarding', authenticate, async (req, res) => {
  try {
    const { age, gender, height, weight, goal, experienceLevel, workoutDaysPerWeek, equipmentAccess } = req.body;
    
    // Validate required fields
    if (!age || !gender || !height || !weight || !goal || !experienceLevel) {
      return res.status(400).json({ message: 'All fields are required' });
    }
    
    // Convert height to cm if needed (assuming frontend sends in cm)
    const heightInCm = height;
    const weightInKg = weight;
    
    const updateData = {
      onboardingCompleted: true,
      age: parseInt(age),
      gender,
      height: heightInCm,
      weight: weightInKg,
      goal,
      experienceLevel,
      workoutDaysPerWeek: parseInt(workoutDaysPerWeek) || 3,
      equipmentAccess: equipmentAccess || 'full_gym'
    };
    
    await User.updateOne({ email: req.user.email }, updateData);
    
    res.json({ 
      message: 'Onboarding completed successfully!',
      user: updateData
    });
  } catch (err) {
    res.status(500).json({ message: 'Error completing onboarding', error: err.message });
  }
});

// ---------- Activities ----------
app.get('/api/activities', authenticate, async (req, res) => {
  try {
    const activities = await Activity.find({ email: req.user.email }).sort({ _id: -1 });
    res.json(activities);
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
    
    const newActivity = await Activity.create({
      email: req.user.email,
      activity: activity.trim(),
      duration_min: Number(duration_min),
      calories: Number(calories),
      intensity: intensity || null,
      type: type || null,
      entry_date: getTodayUTC()
    });
    
    res.status(201).json(newActivity);
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
    
    const updated = await Activity.findOneAndUpdate(
      { _id: id, email: req.user.email },
      { activity: activity.trim(), duration_min: Number(duration_min), calories: Number(calories), intensity, type },
      { new: true }
    );
    
    if (!updated) return res.status(404).json({ message: 'Activity not found' });
    res.json(updated);
  } catch (err) {
    res.status(500).json({ message: 'Error updating activity', error: err.message });
  }
});

app.delete('/api/activities/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await Activity.findOneAndDelete({ _id: id, email: req.user.email });
    if (!deleted) return res.status(404).json({ message: 'Activity not found' });
    res.json({ message: 'Activity deleted', activity: deleted });
  } catch (err) {
    res.status(500).json({ message: 'Error deleting activity', error: err.message });
  }
});

// ---------- Food ----------
app.get('/api/food', authenticate, async (req, res) => {
  try {
    const foods = await Food.find({ email: req.user.email }).sort({ _id: -1 });
    res.json(foods);
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
    
    const newFood = await Food.create({
      email: req.user.email,
      name: name.trim(),
      calories: Number(calories),
      protein: Number(protein),
      sugar: Number(sugar),
      carbs: carbs ? Number(carbs) : null,
      fat: fat ? Number(fat) : null,
      meal_type: mealType || null,
      entry_date: getTodayUTC()
    });
    
    res.status(201).json(newFood);
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
    
    const updated = await Food.findOneAndUpdate(
      { _id: id, email: req.user.email },
      { name: name.trim(), calories: Number(calories), protein: Number(protein), sugar: Number(sugar), carbs: carbs ? Number(carbs) : null, fat: fat ? Number(fat) : null, meal_type: mealType || null },
      { new: true }
    );
    
    if (!updated) return res.status(404).json({ message: 'Food entry not found' });
    res.json(updated);
  } catch (err) {
    res.status(500).json({ message: 'Error updating food', error: err.message });
  }
});

app.delete('/api/food/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await Food.findOneAndDelete({ _id: id, email: req.user.email });
    if (!deleted) return res.status(404).json({ message: 'Food entry not found' });
    res.json({ message: 'Food entry deleted', food: deleted });
  } catch (err) {
    res.status(500).json({ message: 'Error deleting food', error: err.message });
  }
});

// ---------- Sleep ----------
app.get('/api/sleep', authenticate, async (req, res) => {
  try {
    const sleeps = await Sleep.find({ email: req.user.email }).sort({ _id: -1 });
    res.json(sleeps);
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
    
    const newSleep = await Sleep.create({
      email: req.user.email,
      hours: Number(hours),
      quality: quality.trim(),
      bedtime: bedtime || null,
      wake_time: wakeTime || null,
      entry_date: getTodayUTC()
    });
    
    res.status(201).json(newSleep);
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
    
    const updated = await Sleep.findOneAndUpdate(
      { _id: id, email: req.user.email },
      { hours: Number(hours), quality: quality.trim(), bedtime: bedtime || null, wake_time: wakeTime || null },
      { new: true }
    );
    
    if (!updated) return res.status(404).json({ message: 'Sleep entry not found' });
    res.json(updated);
  } catch (err) {
    res.status(500).json({ message: 'Error updating sleep', error: err.message });
  }
});

app.delete('/api/sleep/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await Sleep.findOneAndDelete({ _id: id, email: req.user.email });
    if (!deleted) return res.status(404).json({ message: 'Sleep entry not found' });
    res.json({ message: 'Sleep entry deleted', sleep: deleted });
  } catch (err) {
    res.status(500).json({ message: 'Error deleting sleep', error: err.message });
  }
});

// ---------- Goals ----------
app.get('/api/goals', authenticate, async (req, res) => {
  try {
    const goals = await Goals.findOne({ email: req.user.email });
    res.json(goals || {});
  } catch (err) {
    res.status(500).json({ message: 'Error fetching goals', error: err.message });
  }
});

app.post('/api/goals', authenticate, async (req, res) => {
  try {
    const { dailyCalories, weeklyWorkouts, dailySteps, weeklyWeight, sleepHours, waterIntake } = req.body;
    
    const goals = await Goals.findOneAndUpdate(
      { email: req.user.email },
      {
        daily_calories: dailyCalories || null,
        weekly_workouts: weeklyWorkouts || null,
        daily_steps: dailySteps || null,
        weekly_weight: weeklyWeight || null,
        sleep_hours: sleepHours || null,
        water_intake: waterIntake || null,
        updated_at: new Date()
      },
      { new: true, upsert: true }
    );
    
    res.json({ message: 'Goals saved successfully', goals });
  } catch (err) {
    res.status(500).json({ message: 'Error saving goals', error: err.message });
  }
});

// ---------- Workouts ----------
app.get('/api/workouts', authenticate, async (req, res) => {
  try {
    const workouts = await Workout.find({ email: req.user.email }).sort({ _id: -1 });
    res.json(workouts);
  } catch (err) {
    res.status(500).json({ message: 'Error fetching workouts', error: err.message });
  }
});

app.post('/api/workouts', authenticate, async (req, res) => {
  try {
    const { name, exercises } = req.body;
    if (!name) return res.status(400).json({ message: 'Workout name is required' });
    
    const newWorkout = await Workout.create({
      email: req.user.email,
      name: name.trim(),
      exercises: exercises || []
    });
    
    res.status(201).json(newWorkout);
  } catch (err) {
    res.status(500).json({ message: 'Error creating workout', error: err.message });
  }
});

app.put('/api/workouts/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const { name, exercises } = req.body;
    if (!name) return res.status(400).json({ message: 'Workout name is required' });
    
    const updated = await Workout.findOneAndUpdate(
      { _id: id, email: req.user.email },
      { name: name.trim(), exercises: exercises || [], updated_at: new Date() },
      { new: true }
    );
    
    if (!updated) return res.status(404).json({ message: 'Workout not found' });
    res.json(updated);
  } catch (err) {
    res.status(500).json({ message: 'Error updating workout', error: err.message });
  }
});

app.delete('/api/workouts/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await Workout.findOneAndDelete({ _id: id, email: req.user.email });
    if (!deleted) return res.status(404).json({ message: 'Workout not found' });
    res.json({ message: 'Workout deleted', workout: deleted });
  } catch (err) {
    res.status(500).json({ message: 'Error deleting workout', error: err.message });
  }
});

// ---------- Recent Logs ----------
app.get('/api/recent', authenticate, async (req, res) => {
  try {
    const email = req.user.email;
    const today = getTodayUTC();
    
    const [activities, foods, sleeps] = await Promise.all([
      Activity.find({ email, entry_date: today }).sort({ _id: -1 }),
      Food.find({ email, entry_date: today }).sort({ _id: -1 }),
      Sleep.find({ email, entry_date: today }).sort({ _id: -1 })
    ]);
    
    let logs = [
      ...activities.map(r => ({ ...r.toObject(), type: 'activity', entry_time: r.created_at })),
      ...foods.map(r => ({ ...r.toObject(), type: 'food', entry_time: r.created_at })),
      ...sleeps.map(r => ({ ...r.toObject(), type: 'sleep', entry_time: r.created_at }))
    ];
    
    logs.sort((a, b) => new Date(b.entry_time) - new Date(a.entry_time));
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
    
    const [acts, foods, sleeps] = await Promise.all([
      Activity.find({ email, entry_date: today }),
      Food.find({ email, entry_date: today }),
      Sleep.find({ email, entry_date: today })
    ]);
    
    await Promise.all([
      Activity.deleteMany({ email, entry_date: today }),
      Food.deleteMany({ email, entry_date: today }),
      Sleep.deleteMany({ email, entry_date: today })
    ]);
    
    res.json({
      message: 'Today\'s logs deleted',
      removed: {
        activities: acts,
        food: foods,
        sleep: sleeps
      },
      counts: { activities: acts.length, food: foods.length, sleep: sleeps.length }
    });
  } catch (err) {
    res.status(500).json({ message: 'Error resetting today\'s logs', error: err.message });
  }
});

// ---------- Admin Routes ----------
app.get('/api/admin/users', authenticate, requireAdmin, async (_req, res) => {
  try {
    const users = await User.find({}, 'name email created_at is_admin').sort({ _id: -1 });
    res.json(users);
  } catch (err) {
    res.status(500).json({ message: 'Error fetching users', error: err.message });
  }
});

app.get('/api/admin/user/:email/entries', authenticate, requireAdmin, async (req, res) => {
  try {
    let email = String(req.params.email || '').toLowerCase();
    if (!validateEmail(email)) return res.status(400).json({ message: 'Invalid email' });
    
    const [activities, food, sleep] = await Promise.all([
      Activity.find({ email }).sort({ _id: -1 }),
      Food.find({ email }).sort({ _id: -1 }),
      Sleep.find({ email }).sort({ _id: -1 })
    ]);
    
    res.json({ activities, food, sleep });
  } catch (err) {
    res.status(500).json({ message: 'Error fetching user entries', error: err.message });
  }
});

app.post('/api/admin/user/:email/reset-today', authenticate, requireAdmin, async (req, res) => {
  try {
    let email = String(req.params.email || '').toLowerCase();
    if (!validateEmail(email)) return res.status(400).json({ message: 'Invalid email' });
    const today = getTodayUTC();
    
    const [a, f, s] = await Promise.all([
      Activity.deleteMany({ email, entry_date: today }),
      Food.deleteMany({ email, entry_date: today }),
      Sleep.deleteMany({ email, entry_date: today })
    ]);
    
    res.json({ 
      message: 'User today reset', 
      counts: { activities: a.deletedCount, food: f.deletedCount, sleep: s.deletedCount } 
    });
  } catch (err) {
    res.status(500).json({ message: 'Error resetting user today', error: err.message });
  }
});

// ---------- Dashboard Data ----------
app.get('/api/dashboard-data', authenticate, async (req, res) => {
  try {
    const email = req.user.email;
    const today = getTodayUTC();
    
    const [activities, food, sleep, user] = await Promise.all([
      Activity.find({ email, entry_date: today }),
      Food.find({ email, entry_date: today }),
      Sleep.find({ email, entry_date: today }),
      User.findOne({ email })
    ]);
    
    const totalBurned = activities.reduce((sum, r) => sum + Number(r.calories), 0);
    const workoutCount = activities.length;
    const totalConsumed = food.reduce((sum, r) => sum + Number(r.calories), 0);
    const totalSleepHours = sleep.reduce((sum, r) => sum + Number(r.hours), 0);
    const maintenance = calculateMaintenance(user?.profile || null);
    
    const cards = [
      { label: 'Total Workouts', value: workoutCount, route: '/dashboard/activities' },
      { label: 'Calories Burned', value: `${totalBurned} kcal`, route: '/dashboard/activities' },
      { label: 'Calories Consumed', value: `${totalConsumed} kcal`, route: '/dashboard/food' },
      { label: 'Sleep (hrs)', value: `${totalSleepHours}`, route: '/dashboard/sleep' }
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

// ---------- AI Plans Routes ----------
app.get('/api/ai/plans', authenticate, async (req, res) => {
  try {
    const plans = await AIPlan.find({ email: req.user.email }).sort({ created_at: -1 });
    res.json(plans);
  } catch (err) {
    res.status(500).json({ message: 'Error fetching AI plans', error: err.message });
  }
});

app.post('/api/ai/plans', authenticate, async (req, res) => {
  try {
    const { plan, answers, userStatsSnapshot } = req.body;
    if (!plan) return res.status(400).json({ message: 'Plan is required' });
    
    const newPlan = await AIPlan.create({
      email: req.user.email,
      plan: plan.trim(),
      answers: answers || [],
      userStatsSnapshot: userStatsSnapshot || {}
    });
    
    res.status(201).json(newPlan);
  } catch (err) {
    res.status(500).json({ message: 'Error saving AI plan', error: err.message });
  }
});

app.delete('/api/ai/plans/:id', authenticate, async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await AIPlan.findOneAndDelete({ _id: id, email: req.user.email });
    if (!deleted) return res.status(404).json({ message: 'AI plan not found' });
    res.json({ message: 'AI plan deleted', plan: deleted });
  } catch (err) {
    res.status(500).json({ message: 'Error deleting AI plan', error: err.message });
  }
});

// ---------- AI Error Management Routes ----------
app.get('/api/admin/ai-errors', authenticate, requireAdmin, async (req, res) => {
  try {
    const { page = 1, limit = 20, status, severity, errorType } = req.query;
    const skip = (page - 1) * limit;
    
    let filter = {};
    if (status) filter.status = status;
    if (severity) filter.severity = severity;
    if (errorType) filter.errorType = errorType;
    
    const [errors, total] = await Promise.all([
      AIError.find(filter)
        .sort({ created_at: -1 })
        .skip(skip)
        .limit(parseInt(limit))
        .lean(),
      AIError.countDocuments(filter)
    ]);
    
    res.json({
      errors,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (err) {
    res.status(500).json({ message: 'Error fetching AI errors', error: err.message });
  }
});

app.get('/api/admin/ai-errors/stats', authenticate, requireAdmin, async (req, res) => {
  try {
    const AIErrorLogger = require('./utils/errorLogger');
    const stats = await AIErrorLogger.getErrorStats();
    res.json(stats);
  } catch (err) {
    res.status(500).json({ message: 'Error fetching AI error stats', error: err.message });
  }
});

app.get('/api/admin/ai-errors/:id', authenticate, requireAdmin, async (req, res) => {
  try {
    const AIErrorLogger = require('./utils/errorLogger');
    const error = await AIErrorLogger.getErrorById(req.params.id);
    if (!error) return res.status(404).json({ message: 'Error not found' });
    res.json(error);
  } catch (err) {
    res.status(500).json({ message: 'Error fetching AI error', error: err.message });
  }
});

app.put('/api/admin/ai-errors/:id/status', authenticate, requireAdmin, async (req, res) => {
  try {
    const { status, adminNotes } = req.body;
    const AIErrorLogger = require('./utils/errorLogger');
    const error = await AIErrorLogger.updateErrorStatus(
      req.params.id, 
      status, 
      adminNotes, 
      req.user.email
    );
    if (!error) return res.status(404).json({ message: 'Error not found' });
    res.json(error);
  } catch (err) {
    res.status(500).json({ message: 'Error updating AI error status', error: err.message });
  }
});

app.delete('/api/admin/ai-errors/:id', authenticate, requireAdmin, async (req, res) => {
  try {
    const deleted = await AIError.findByIdAndDelete(req.params.id);
    if (!deleted) return res.status(404).json({ message: 'Error not found' });
    res.json({ message: 'AI error deleted successfully' });
  } catch (err) {
    res.status(500).json({ message: 'Error deleting AI error', error: err.message });
  }
});

app.post('/api/admin/ai-errors/cleanup', authenticate, requireAdmin, async (req, res) => {
  try {
    const { daysOld = 30 } = req.body;
    const AIErrorLogger = require('./utils/errorLogger');
    const deletedCount = await AIErrorLogger.deleteOldErrors(daysOld);
    res.json({ message: `Cleaned up ${deletedCount} old AI errors` });
  } catch (err) {
    res.status(500).json({ message: 'Error cleaning up AI errors', error: err.message });
  }
});

// ---------- AI Routes ----------
const aiRoutes = require('./routes/ai');
app.use('/api/ai', aiRoutes);

// ---------- AI Credits (after AI routes to avoid conflicts) ----------
app.get('/api/ai/credits', authenticate, async (req, res) => {
  try {
    const user = await User.findOne({ email: req.user.email });
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    // Check and reset credits if needed
    checkHourlyReset(user);
    checkDailyReset(user);
    await user.save();
    
    const timeUntilHourlyReset = getTimeUntilHourlyReset(user);
    const hoursUntilMidnight = getHoursUntilMidnight();
    
    res.json({
      hourly: {
        remaining: user.aiCreditsRemaining,
        limit: 5,
        resetTime: timeUntilHourlyReset
      },
      daily: {
        used: user.aiDailyCreditsUsed,
        limit: 20,
        resetTime: hoursUntilMidnight
      }
    });
  } catch (err) {
    res.status(500).json({ message: 'Error fetching AI credits', error: err.message });
  }
});

// ---------- Start Server ----------
const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`🟢 Server running on http://localhost:${PORT}`));

