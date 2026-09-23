const express = require('express');

const store = require('../data');
const { asyncHandler } = require('../lib/errors');
const { authenticate } = require('../lib/auth');
const v = require('../lib/validate');
const { requireUser, entryDateFor } = require('../lib/users');
const sync = require('../lib/sync');

const router = express.Router();
router.use(authenticate);

// Water is stored in millilitres. It used to be counted in "glasses", which is
// not a unit. Existing clients still speak glasses, so both directions convert
// at this boundary and nothing downstream has to care.
const ML_PER_GLASS = 250;

const toGlasses = (ml) => Math.round((ml / ML_PER_GLASS) * 10) / 10;

function respond(res, doc, entryDate) {
  const ml = Math.max(0, Math.round(doc?.ml || 0));
  res.json({
    id: doc?.id ?? null,
    ml,
    glasses: toGlasses(ml),
    entry_date: entryDate,
    revision: doc ? (doc.revision ?? 1) : 0,
  });
}

router.get(
  '/',
  asyncHandler(async (req, res) => {
    const user = await requireUser(req.user.email);
    const entryDate = entryDateFor(req, user);
    const doc = await store.findOne('water', { email: user.email, entry_date: entryDate });
    respond(res, doc, entryDate);
  })
);

router.post(
  '/',
  asyncHandler(async (req, res) => {
    const user = await requireUser(req.user.email);
    const entryDate = entryDateFor(req, user);
    const body = req.body || {};
    const filter = { email: user.email, entry_date: entryDate };
    const previous = await store.findOne('water', filter);

    const deltaMl =
      body.deltaMl != null
        ? v.num(body.deltaMl, 'deltaMl', { min: -5000, max: 5000 })
        : body.delta != null
          ? v.num(body.delta, 'delta', { min: -20, max: 20 }) * ML_PER_GLASS
          : null;

    // The mutation transaction serializes additions across devices. Each delta
    // has its own replayable operation key; it must not replace a stale total.
    // Absolute totals can opt into revision checks; older installed clients remain compatible.
    if (deltaMl == null)
      sync.checkRevision(req, previous ?? { revision: 0, ml: 0, entry_date: entryDate });
    const ml =
      deltaMl != null
        ? Math.max(0, (previous?.ml ?? 0) + deltaMl)
        : body.ml != null
          ? v.num(body.ml, 'ml', { min: 0, max: 30000 })
          : v.num(body.glasses, 'glasses', { min: 0, max: 100 }) * ML_PER_GLASS;

    const doc = await store.upsert('water', filter, {
      ml: Math.round(ml),
      account_id: user.id,
      revision: (previous ? (previous.revision ?? 1) : 0) + 1,
      updated_at: new Date(),
    });
    await sync.change(user, 'water', { ...doc, client_id: entryDate });
    respond(res, doc, entryDate);
  })
);

module.exports = router;
