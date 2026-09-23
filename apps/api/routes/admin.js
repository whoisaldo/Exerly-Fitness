const express = require('express');

const store = require('../data');
const { asyncHandler, notFound, badRequest, forbidden } = require('../lib/errors');
const { authenticate, requireAdmin } = require('../lib/auth');
const v = require('../lib/validate');
const { timezoneFor, serializeUser } = require('../lib/users');
const dates = require('../lib/dates');
const AIErrorLogger = require('../utils/errorLogger');

const router = express.Router();
router.use(authenticate, requireAdmin);

router.get(
  '/users',
  asyncHandler(async (req, res) => {
    const limit = Math.min(500, Math.max(1, parseInt(req.query.limit, 10) || 200));
    const users = await store.find('users', {}, { sort: { id: -1 }, limit });
    // The password hash must never leave the database, not even for an admin.
    res.json(
      users.map((u) => ({
        _id: u.id,
        name: u.name,
        email: u.email,
        created_at: u.created_at,
        is_admin: !!u.is_admin,
        onboardingCompleted: !!u.onboardingCompleted,
      }))
    );
  })
);

router.get(
  '/stats',
  asyncHandler(async (req, res) => {
    const today = dates.today(timezoneFor(null, req));

    const [
      totalUsers,
      actEmails,
      foodEmails,
      sleepEmails,
      totalAct,
      totalFood,
      totalSleep,
      totalWeights,
    ] = await Promise.all([
      store.count('users', {}),
      store.distinct('activities', 'email', { entry_date: today }),
      store.distinct('food', 'email', { entry_date: today }),
      store.distinct('sleep', 'email', { entry_date: today }),
      store.count('activities', {}),
      store.count('food', {}),
      store.count('sleep', {}),
      store.count('weights', {}),
    ]);

    const active = new Set([...actEmails, ...foodEmails, ...sleepEmails]);

    res.json({
      totalUsers,
      activeToday: active.size,
      totalEntries: totalAct + totalFood + totalSleep + totalWeights,
      breakdown: {
        activities: totalAct,
        food: totalFood,
        sleep: totalSleep,
        weights: totalWeights,
      },
    });
  })
);

router.get(
  '/user/:email/entries',
  asyncHandler(async (req, res) => {
    const email = v.email(req.params.email);
    const [activities, food, sleep, weights] = await Promise.all([
      store.find('activities', { email }, { sort: { id: -1 }, limit: 500 }),
      store.find('food', { email }, { sort: { id: -1 }, limit: 500 }),
      store.find('sleep', { email }, { sort: { id: -1 }, limit: 500 }),
      store.find('weights', { email }, { sort: { entry_date: -1 }, limit: 500 }),
    ]);
    res.json({ activities, food, sleep, weights });
  })
);

router.post(
  '/user/:email/reset-today',
  asyncHandler(async (req, res) => {
    const email = v.email(req.params.email);
    const target = await store.findOne('users', { email });
    if (!target) throw notFound('User not found');

    const removed = await require('../lib/deleteDayLogs')(
      target,
      dates.today(target.timezone || 'UTC')
    );
    const counts = Object.fromEntries(
      Object.entries(removed).map(([key, rows]) => [key, rows.length])
    );
    res.json({ message: 'User today reset', counts });
  })
);

router.post(
  '/toggle-admin',
  asyncHandler(async (req, res) => {
    const email = v.email(req.body.email);
    const isAdmin = !!req.body.isAdmin;

    // An admin demoting themselves can lock everyone out of the panel, and
    // there's no other way back in short of editing the database.
    if (email === String(req.user.email).toLowerCase() && !isAdmin) {
      throw forbidden('You cannot remove your own admin access');
    }

    const user = await store.findOne('users', { email });
    if (!user) throw notFound('User not found');

    await store.update('users', { id: user.id }, { is_admin: isAdmin });
    res.json({ message: `Admin status updated for ${email}`, isAdmin });
  })
);

router.get(
  '/user/:email',
  asyncHandler(async (req, res) => {
    const email = v.email(req.params.email);
    const user = await store.findOne('users', { email });
    if (!user) throw notFound('User not found');
    res.json(serializeUser(user));
  })
);

// ---------- AI error inspection ----------

router.get(
  '/ai-errors',
  asyncHandler(async (req, res) => {
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit, 10) || 20));

    // Only primitive strings become filters, so ?status[$ne]=RESOLVED arrives
    // as an object and is ignored rather than reaching the query layer.
    const filter = {};
    for (const key of ['status', 'severity', 'errorType']) {
      if (typeof req.query[key] === 'string') filter[key] = req.query[key];
    }

    const [errors, total] = await Promise.all([
      store.find('ai_errors', filter, {
        sort: { created_at: -1 },
        limit,
        skip: (page - 1) * limit,
      }),
      store.count('ai_errors', filter),
    ]);

    res.json({ errors, pagination: { page, limit, total, pages: Math.ceil(total / limit) } });
  })
);

router.get(
  '/ai-errors/stats',
  asyncHandler(async (_req, res) => {
    res.json(await AIErrorLogger.getErrorStats());
  })
);

router.get(
  '/ai-errors/:id',
  asyncHandler(async (req, res) => {
    const error = await AIErrorLogger.getErrorById(req.params.id);
    if (!error) throw notFound('Error not found');
    res.json(error);
  })
);

router.put(
  '/ai-errors/:id/status',
  asyncHandler(async (req, res) => {
    const updated = await AIErrorLogger.updateErrorStatus(
      req.params.id,
      req.body.status,
      req.body.adminNotes,
      req.user.email
    );
    if (!updated) throw notFound('Error not found');
    res.json(updated);
  })
);

router.delete(
  '/ai-errors/:id',
  asyncHandler(async (req, res) => {
    const deleted = await store.removeOne('ai_errors', { id: String(req.params.id) });
    if (!deleted) throw notFound('Error not found');
    res.json({ message: 'AI error deleted successfully' });
  })
);

router.post(
  '/ai-errors/cleanup',
  asyncHandler(async (req, res) => {
    const daysOld =
      v.int(req.body.daysOld, 'daysOld', { required: false, min: 1, max: 3650 }) ?? 30;
    const deleted = await AIErrorLogger.deleteOldErrors(daysOld);
    res.json({ message: `Cleaned up ${deleted} old AI errors` });
  })
);

router.use((req, _res, next) => next(badRequest(`Unknown admin route: ${req.path}`)));

module.exports = router;
