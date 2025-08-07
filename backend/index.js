// backend/index.js
const express = require('express');
const cors    = require('cors');
const bcrypt  = require('bcrypt');
const jwt     = require('jsonwebtoken');

const app    = express();
const SECRET = process.env.JWT_SECRET || 'fallback-secret';

app.use(cors());
app.use(express.json());

// In-memory stores
const users            = [];
const activityEntries  = [];   // { id, email, activity, duration_min, calories, entry_date }
let nextActivityId     = 1;
const foodEntries      = [];   // { id, email, name, calories, protein, sugar, entry_date }
let nextFoodId         = 1;

// Health check
app.get('/ping', (_req, res) => res.send('pong'));

// ── Auth routes ─────────────────────────────────────
// Sign up
app.post('/signup', async (req, res) => {
  const { name, email, password } = req.body;
  if (!name||!email||!password) return res.status(400).json({ message: 'Name, email & password required' });
  if (users.find(u=>u.email===email)) return res.status(409).json({ message: 'User exists' });
  const hash = await bcrypt.hash(password, 10);
  users.push({ name, email, hash });
  res.json({ message: 'Signup successful' });
});

// Login
app.post('/login', async (req, res) => {
  const { email, password } = req.body;
  const user = users.find(u=>u.email===email);
  if (!user) return res.status(401).json({ message: 'Invalid credentials' });
  if (!await bcrypt.compare(password, user.hash)) {
    return res.status(401).json({ message: 'Invalid credentials' });
  }
  const token = jwt.sign({ email:user.email, name:user.name }, SECRET, { expiresIn:'1h' });
  res.json({ token });
});
// ────────────────────────────────────────────────────

// Auth middleware
function authenticate(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth) return res.status(401).json({ message:'No token provided' });
  const token = auth.split(' ')[1];
  try {
    req.user = jwt.verify(token, SECRET);
    next();
  } catch {
    res.status(401).json({ message:'Invalid or expired token' });
  }
}

// ── Activity endpoints ─────────────────────────────
// GET all activities for user
app.get('/api/activities', authenticate, (req, res) => {
  const email = req.user.email;
  const list = activityEntries.filter(e=>e.email===email)
    .sort((a,b)=>b.id-a.id);
  res.json(list);
});

// POST a new activity
app.post('/api/activities', authenticate, (req, res) => {
  const { activity, duration_min, calories } = req.body;
  if (!activity||duration_min==null||calories==null) {
    return res.status(400).json({ message:'All fields required' });
  }
  const entry = {
    id:           nextActivityId++,
    email:        req.user.email,
    activity,
    duration_min: Number(duration_min),
    calories:     Number(calories),
    entry_date:   new Date().toISOString().slice(0,10),
  };
  activityEntries.push(entry);
  res.status(201).json(entry);
});

// ── Food endpoints ─────────────────────────────────
// GET all food entries for user
app.get('/api/food', authenticate, (req, res) => {
  const email = req.user.email;
  const list = foodEntries.filter(f=>f.email===email)
    .sort((a,b)=>b.id-a.id);
  res.json(list);
});

// POST a new food entry
app.post('/api/food', authenticate, (req, res) => {
  const { name, calories, protein, sugar } = req.body;
  if (!name||calories==null||protein==null||sugar==null) {
    return res.status(400).json({ message:'All fields required' });
  }
  const entry = {
    id:         nextFoodId++,
    email:      req.user.email,
    name,
    calories:   Number(calories),
    protein:    Number(protein),
    sugar:      Number(sugar),
    entry_date: new Date().toISOString().slice(0,10),
  };
  foodEntries.push(entry);
  res.status(201).json(entry);
});

// ── Dashboard-data (today’s summaries) ─────────────
app.get('/api/dashboard-data', authenticate, (req, res) => {
  const email = req.user.email;
  const today = new Date().toISOString().slice(0,10);

  const todaysActivities = activityEntries.filter(
    e => e.email===email && e.entry_date===today
  );
  const totalBurned   = todaysActivities.reduce((s,e)=>s+e.calories,0);
  const workoutCount  = todaysActivities.length;

  const todaysFood = foodEntries.filter(
    f => f.email===email && f.entry_date===today
  );
  const totalConsumed  = todaysFood.reduce((s,f)=>s+f.calories,0);
  const proteinTotal   = todaysFood.reduce((s,f)=>s+f.protein,  0);
  const sugarTotal     = todaysFood.reduce((s,f)=>s+f.sugar,    0);

  res.json([
    { label:'Total Workouts',     value:workoutCount,            route:'/dashboard/workouts' },
    { label:'Calories Burned',    value:`${totalBurned} kcal`,   route:'/dashboard/activities' },
    { label:'Calories Consumed',  value:`${totalConsumed} kcal`, route:'/dashboard/food' },
    { label:'Protein Consumed',   value:`${proteinTotal} g`,     route:'/dashboard/food' },
    { label:'Sugar Consumed',     value:`${sugarTotal} g`,       route:'/dashboard/food' },
  ]);
});

// Start server
const PORT = process.env.PORT||3001;
app.listen(PORT, ()=> console.log(`🟢 Server running on http://localhost:${PORT}`));
