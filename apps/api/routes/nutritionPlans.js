// /v1/nutrition: plans for accounts set up before nutrition plans existed.
// Only the person's own app may ask; personal access tokens can't.

const express = require('express');
const { asyncHandler, forbidden } = require('../lib/errors');
const { authenticate } = require('../lib/auth');
const { requireUser } = require('../lib/users');
const { adoptLegacyTargets } = require('../lib/nutrition/legacyPlans');

const router = express.Router();
router.use(authenticate);

// Keeps the targets an account already has, as manual plans, the first time
// the app finds it has none. Safe to call again: it changes nothing then.
router.post(
  '/plans/from-legacy',
  asyncHandler(async (req, res) => {
    if (req.pat) throw forbidden('Only the Exerly app can do this.');
    const user = await requireUser(req.user.email);
    const { plans, reason } = await adoptLegacyTargets(user);
    res.status(plans.length ? 201 : 200).json({ created: plans.length, reason, plans });
  })
);

module.exports = router;
