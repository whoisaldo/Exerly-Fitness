const express = require('express');
const store = require('../data');
const { authenticate } = require('../lib/auth');
const { asyncHandler } = require('../lib/errors');
const v = require('../lib/validate');
const router = express.Router();
router.use(authenticate);
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const after = v.int(req.query.after ?? 0, 'after', { min: 0 });
    const changes = await store.find(
      'sync_changes',
      { account_id: req.account.id, sequence: { gt: after } },
      { sort: { sequence: 1 }, limit: 500 }
    );
    res.json({
      changes,
      cursor: changes.at(-1)?.sequence ?? after,
      has_more: changes.length === 500,
    });
  })
);
module.exports = router;
