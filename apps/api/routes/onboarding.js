const express = require('express');
const store = require('../data');
const { asyncHandler, badRequest, conflict } = require('../lib/errors');
const { authenticate } = require('../lib/auth');
const { requireUser } = require('../lib/users');
const setup = require('../lib/onboarding');
const v = require('../lib/validate');

const router = express.Router();
router.use(authenticate);

router.get(
  '/api/bootstrap',
  asyncHandler(async (req, res) => {
    const user = await requireUser(req.user.email);
    const onboarding = await setup.repairIfPossible(user);
    res.json({
      account: onboarding.user,
      account_id: user.id,
      onboarding,
      targets: onboarding.targets,
      contract_version: 1,
      features: {
        social: false,
        ai: false,
        photo_backup: false,
        adaptive_nutrition: process.env.ADAPTIVE_NUTRITION_ENABLED === 'true',
      },
    });
  })
);

router.get(
  '/api/onboarding/status',
  asyncHandler(async (req, res) => {
    res.json(await setup.status(await requireUser(req.user.email)));
  })
);

router.get(
  '/api/onboarding/draft',
  asyncHandler(async (req, res) => {
    const user = await requireUser(req.user.email);
    res.json({ draft: await store.findOne('onboarding_drafts', { account_id: user.id }) });
  })
);

router.put(
  '/api/onboarding/draft',
  asyncHandler(async (req, res) => {
    const user = await requireUser(req.user.email);
    const old = await store.findOne('onboarding_drafts', { account_id: user.id });
    if (user.onboardingCompleted && (await setup.status(user)).complete)
      throw conflict('Setup is already complete');
    const revision = v.int(req.body.revision, 'revision', { min: 0 });
    if (revision !== (old?.revision ?? 0)) throw conflict('A newer setup draft exists');
    if (![1, 2].includes(req.body.schema_version))
      throw badRequest('Unsupported draft schema version');
    if (
      !req.body.answers ||
      typeof req.body.answers !== 'object' ||
      Array.isArray(req.body.answers)
    )
      throw badRequest('answers must be an object');
    const lastStep = v.int(req.body.last_valid_step, 'last_valid_step', {
      min: 0,
      max: req.body.schema_version === 2 ? 4 : 11,
    });
    const draft = await store.upsert(
      'onboarding_drafts',
      { account_id: user.id },
      {
        answers: req.body.answers,
        schema_version: req.body.schema_version,
        revision: revision + 1,
        last_valid_step: lastStep,
        updated_at: new Date(),
      }
    );
    res.json({ draft });
  })
);

router.post(
  '/api/onboarding/preview',
  asyncHandler(async (req, res) => {
    const preview = setup.validateAnswers(req.body, await requireUser(req.user.email));
    res.json({
      targets: preview.targets,
      maintenance: preview.maintenance,
      program: preview.program,
    });
  })
);

router.post(
  '/api/onboarding/complete',
  asyncHandler(async (req, res) => {
    if (!req.get('Idempotency-Key')) throw badRequest('Idempotency-Key is required');
    res.json(await setup.complete(req.user.email, req.body));
  })
);

module.exports = router;
