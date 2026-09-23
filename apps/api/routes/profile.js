const express = require('express');

const { asyncHandler, badRequest } = require('../lib/errors');
const { authenticate } = require('../lib/auth');
const { serializeUser, requireUser, normalizeProfile } = require('../lib/users');
const preferences = require('../lib/preferences');

const router = express.Router();
router.use(authenticate);

router.get(
  '/api/me',
  asyncHandler(async (req, res) => {
    res.json(serializeUser(await requireUser(req.user.email)));
  })
);

router.get(
  '/api/profile',
  asyncHandler(async (req, res) => {
    const user = await requireUser(req.user.email);
    res.json(normalizeProfile(user.profile));
  })
);

router.get(
  '/api/preferences',
  asyncHandler(async (req, res) => {
    res.json(preferences.envelope(await requireUser(req.user.email)));
  })
);

router.patch(
  '/api/preferences',
  asyncHandler(async (req, res) => {
    if (!req.get('Idempotency-Key')) throw badRequest('Idempotency-Key is required');
    res.json(
      await preferences.apply(await requireUser(req.user.email), req.body.changes, {
        baseRevision: req.body.base_revision,
      })
    );
  })
);

router.post(
  '/api/profile',
  asyncHandler(async (req, res) => {
    const result = await preferences.applyLegacy(await requireUser(req.user.email), req.body);
    const user = await requireUser(req.user.email);
    res.json({
      message: 'Profile saved',
      profile: normalizeProfile(user.profile),
      user: result.user,
    });
  })
);

router.put(
  '/api/profile',
  asyncHandler(async (req, res) => {
    const result = await preferences.applyLegacy(await requireUser(req.user.email), req.body);
    res.json({ message: 'Profile saved', user: result.user });
  })
);

router.put(
  '/api/settings',
  asyncHandler(async (req, res) => {
    const changes = {};
    for (const key of ['timezone', 'unitSystem']) {
      if (Object.prototype.hasOwnProperty.call(req.body, key)) changes[key] = req.body[key];
    }
    const result = await preferences.apply(await requireUser(req.user.email), changes, {
      legacy: true,
    });
    res.json({ message: 'Settings saved', user: result.user });
  })
);

// Compatibility route for installed clients. Both paths use the same transaction.
router.post(
  '/api/user/onboarding',
  asyncHandler(async (req, res) => {
    res.json(await require('../lib/onboarding').complete(req.user.email, req.body));
  })
);

module.exports = router;
