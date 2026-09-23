const express = require('express');
const bcrypt = require('bcrypt');

const store = require('../data');
const { asyncHandler, unauthorized, conflict } = require('../lib/errors');
const { authenticate, adminEmails } = require('../lib/auth');
const sessions = require('../lib/sessions');
const { rateLimit } = require('../lib/ratelimit');
const v = require('../lib/validate');
const { requireUser } = require('../lib/users');
const { normalizeTimeZone } = require('../lib/dates');

const router = express.Router();

const BCRYPT_ROUNDS = 12;

// Without this, an attacker gets unlimited password guesses against any known
// email address. Ten minutes of lockout after 8 tries makes online guessing
// useless while barely inconveniencing someone who fat-fingered their password.
const loginLimiter = rateLimit({
  name: 'login',
  max: 8,
  windowMs: 10 * 60 * 1000,
  message: 'Too many sign-in attempts. Wait a few minutes and try again.',
});

const signupLimiter = rateLimit({
  name: 'signup',
  max: 5,
  windowMs: 60 * 60 * 1000,
  message: 'Too many accounts created from this address.',
});

router.post(
  '/signup',
  signupLimiter,
  asyncHandler(async (req, res) => {
    const name = v.str(req.body.name, 'name', { max: 80 });
    const email = v.email(req.body.email);
    const password = v.password(req.body.password);
    const timezone = normalizeTimeZone(req.body.timezone || req.get('X-Timezone'));

    const existing = await store.findOne('users', { email });
    if (existing) throw conflict('An account with this email already exists');

    const hash = await bcrypt.hash(password, BCRYPT_ROUNDS);
    const user = await store.insert('users', {
      name,
      email,
      hash,
      is_admin: adminEmails().includes(email),
      timezone,
      unitSystem: req.body.unitSystem === 'imperial' ? 'imperial' : 'metric',
      profile: {},
      created_at: new Date(),
      onboardingCompleted: false,
      aiCreditsRemaining: 5,
      aiDailyCreditsUsed: 0,
      aiLastCreditReset: new Date(),
      aiDailyResetDate: new Date(),
    });

    res
      .status(201)
      .json({ message: 'Signup successful', ...(await sessions.createSession(user, req)) });
  })
);

router.post(
  '/login',
  loginLimiter,
  asyncHandler(async (req, res) => {
    const email = v.email(req.body.email);
    const password = v.str(req.body.password, 'password', { max: 200, trim: false });

    const user = await store.findOne('users', { email });
    // Hash a throwaway password when the user doesn't exist so the response
    // time doesn't reveal which emails are registered.
    if (!user) {
      await bcrypt.compare(password, '$2b$12$invalidinvalidinvalidinvalidinvalidinvalidinvalidinv');
      throw unauthorized('Invalid credentials');
    }

    const ok = await bcrypt.compare(password, user.hash);
    if (!ok) throw unauthorized('Invalid credentials');

    let current = user;
    if (adminEmails().includes(email) && !user.is_admin) {
      current = await store.update('users', { id: user.id }, { is_admin: true });
      if (!current || (current.credentials_version ?? 0) !== (user.credentials_version ?? 0))
        throw unauthorized('Credentials changed. Sign in again.');
    }

    res.json(await sessions.createSession(current, req));
  })
);

// Sliding session. Clients call this on launch so an active user is never
// bounced to the login screen.
router.post(
  '/auth/token',
  rateLimit({ name: 'refresh', max: 60, windowMs: 600000 }),
  asyncHandler(async (req, res) => {
    res.json(await sessions.rotate(req.body.refreshToken, req.get('Idempotency-Key')));
  })
);

router.post(
  '/auth/refresh',
  authenticate,
  rateLimit({
    name: 'compatibility-refresh',
    max: 60,
    windowMs: 600000,
    key: (req) => req.account.id,
  }),
  asyncHandler(
    async (req, res) => {
      const user = await requireUser(req.user.email);
      // Session upgrades have their own replay contract, without persisting
      // usable credentials in the generic operation-response table.
      res.json(await sessions.upgradeSession(user, req));
    },
    { transactional: false }
  )
);

router.post(
  '/api/change-password',
  authenticate,
  rateLimit({ name: 'change-password', max: 10, windowMs: 60 * 60 * 1000 }),
  asyncHandler(async (req, res) => {
    const currentPassword = v.str(req.body.currentPassword, 'currentPassword', {
      max: 200,
      trim: false,
    });
    const newPassword = v.password(req.body.newPassword, 'newPassword');

    const user = await requireUser(req.user.email);
    const ok = await bcrypt.compare(currentPassword, user.hash);
    if (!ok) throw unauthorized('Current password is incorrect');

    await store.update(
      'users',
      { id: user.id },
      {
        hash: await bcrypt.hash(newPassword, BCRYPT_ROUNDS),
        credentials_version: (user.credentials_version ?? 0) + 1,
      }
    );
    await sessions.revokeAll(user.id);
    res.json({ message: 'Password changed successfully' });
  })
);

router.post(
  '/auth/logout',
  authenticate,
  asyncHandler(async (req, res) => {
    if (req.user.sid)
      await store.update(
        'sessions',
        { session_id: req.user.sid, account_id: req.account.id },
        { revoked_at: new Date() }
      );
    else
      await store.update(
        'users',
        { id: req.account.id },
        { credentials_version: (req.account.credentials_version ?? 0) + 1 }
      );
    res.json({ message: 'Signed out' });
  })
);

router.get(
  '/api/sessions',
  authenticate,
  asyncHandler(async (req, res) => {
    const rows = await store.find(
      'sessions',
      { account_id: req.account.id, revoked_at: null },
      { sort: { updated_at: -1 }, limit: 100 }
    );
    res.json(
      rows
        .filter((row) => sessions.isActive(row, req.account))
        .map((row) => ({
          id: row.session_id,
          device_name: row.device_name,
          created_at: row.created_at,
          updated_at: row.updated_at,
          current: row.session_id === req.user.sid,
        }))
    );
  })
);

router.delete(
  '/api/sessions/:id',
  authenticate,
  asyncHandler(async (req, res) => {
    await store.update(
      'sessions',
      { session_id: req.params.id, account_id: req.account.id },
      { revoked_at: new Date() }
    );
    res.json({ message: 'Session revoked' });
  })
);

module.exports = router;
