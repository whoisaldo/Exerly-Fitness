// Isolated simulator fixture: the real application and SQLite adapter with a
// deterministic external food provider. Never reads development/production env.
process.env.NODE_ENV = 'test';
process.env.DB_MODE = 'local';
process.env.JWT_SECRET = 'isolated-ios-fixture-secret';
process.env.ADMIN_EMAILS = '';
const express = require('express');
const jwt = require('jsonwebtoken');
const store = require('../apps/api/data');
const providers = require('../apps/api/lib/foodProviders');
const { createApp } = require('../apps/api/app');
const { reset: resetRateLimits } = require('../apps/api/lib/ratelimit');
let offline = false;
let disconnect = false;
let dropSetupAcknowledgement = false;
let dropPreferencesAcknowledgement = false;
let dropSessionUpgradeAcknowledgement = false;
const sessionUpgradeAttempts = [];
let measurementRoundTrip = null;
let weightRoundTrip = null;
let dailyLogsRoundTrip = null;
let setupRoundTrip = null;
let preferencesRoundTrip = null;
providers.lookupBarcode = async (identity) => ({
  status: 'found',
  food: providers.mapOpenFoodFactsProduct(
    {
      code: '0036000291452',
      product_name: 'Simulator oat drink',
      brands: 'Test fixture',
      quantity: '1 l',
      serving_size: '100 ml',
      nutriments: {
        'energy-kcal_100g': 60,
        proteins_100g: 2,
        carbohydrates_100g: 8,
        fat_100g: 2,
        fiber_100g: 1,
        sugars_100g: 4,
        sodium_100g: 0.04,
        'saturated-fat_100g': 0.2,
      },
    },
    identity.identity
  ),
});
(async () => {
  await store.connect({ file: ':memory:' });
  const app = express();
  app.use('/__test', express.json());
  app.post('/__test/control', async (req, res, next) => {
    if (req.get('X-Test-Fixture') !== 'isolated-simulator') return res.sendStatus(403);
    try {
      if (req.body.repairLegacyEmail) {
        const email = String(req.body.repairLegacyEmail);
        if (!email.endsWith('@exerly.test')) return res.sendStatus(400);
        const user = await store.findOne('users', { email });
        if (!user) return res.sendStatus(404);
        await store.transaction(async () => {
          await store.update(
            'users',
            { id: user.id },
            {
              onboardingCompleted: true,
              age: 34,
              gender: 'female',
              height: 167.5,
              weight: 72.25,
              goal: 'maintain',
              unitSystem: 'metric',
              profile: { sex: 'female', allergies: ['nuts'] },
            }
          );
          await store.remove('programs', { email });
          await store.remove('goals', { email });
        });
      }
      offline = req.body.offline === true;
      disconnect = req.body.disconnect === true;
      dropSetupAcknowledgement = req.body.dropSetupAcknowledgement === true;
      dropPreferencesAcknowledgement = req.body.dropPreferencesAcknowledgement === true;
      dropSessionUpgradeAcknowledgement = req.body.dropSessionUpgradeAcknowledgement === true;
      resetRateLimits();
      res.json({ offline, dropSetupAcknowledgement, dropPreferencesAcknowledgement });
    } catch (error) {
      next(error);
    }
  });
  app.get('/__test/ready', (_req, res) => res.json({ isolated: true }));
  app.post('/__test/legacy-session', async (req, res, next) => {
    if (req.get('X-Test-Fixture') !== 'isolated-simulator') return res.sendStatus(403);
    try {
      if (typeof req.body.email !== 'string' || !req.body.email.endsWith('@exerly.test'))
        return res.sendStatus(400);
      const user = await store.findOne('users', { email: req.body.email });
      if (!user) return res.sendStatus(404);
      res.json({
        token: jwt.sign({ email: user.email, is_admin: false }, process.env.JWT_SECRET, {
          expiresIn: '1h',
        }),
      });
    } catch (error) {
      next(error);
    }
  });
  app.get('/__test/session-upgrades', async (req, res, next) => {
    if (req.get('X-Test-Fixture') !== 'isolated-simulator') return res.sendStatus(403);
    try {
      if (typeof req.query.email !== 'string' || !req.query.email.endsWith('@exerly.test'))
        return res.sendStatus(400);
      const user = await store.findOne('users', { email: req.query.email });
      if (!user) return res.sendStatus(404);
      const sessions = await store.find('sessions', { account_id: user.id });
      res.json({
        count: sessions.length,
        attempts: sessionUpgradeAttempts.filter((attempt) => attempt.email === user.email),
      });
    } catch (error) {
      next(error);
    }
  });
  app.get('/__test/preferences-roundtrip', (req, res) => {
    if (req.get('X-Test-Fixture') !== 'isolated-simulator') return res.sendStatus(403);
    res.json(preferencesRoundTrip || { ready: false });
  });
  app.post('/__test/preferences-roundtrip', async (req, res, next) => {
    if (req.get('X-Test-Fixture') !== 'isolated-simulator') return res.sendStatus(403);
    try {
      const user = await store.findOne('users', { email: req.body.email });
      if (
        !user ||
        !user.email.startsWith('preferences-cross-') ||
        !user.email.endsWith('@exerly.test')
      )
        return res.sendStatus(400);
      if (!user.onboardingCompleted || user.preferences_revision < 2) return res.sendStatus(409);
      if (!['native-saved', 'browser-saved'].includes(req.body.phase)) return res.sendStatus(400);
      preferencesRoundTrip = {
        ready: true,
        email: user.email,
        account_id: user.id,
        phase: req.body.phase,
      };
      res.json(preferencesRoundTrip);
    } catch (error) {
      next(error);
    }
  });
  app.get('/__test/setup-roundtrip', (req, res) => {
    if (req.get('X-Test-Fixture') !== 'isolated-simulator') return res.sendStatus(403);
    res.json(setupRoundTrip || { ready: false });
  });
  app.post('/__test/setup-roundtrip', async (req, res, next) => {
    if (req.get('X-Test-Fixture') !== 'isolated-simulator') return res.sendStatus(403);
    try {
      const user = await store.findOne('users', { email: req.body.email });
      if (!user || !user.email.startsWith('setup-cross-') || !user.email.endsWith('@exerly.test'))
        return res.sendStatus(400);
      if (!['browser-draft', 'native-draft', 'browser-complete'].includes(req.body.phase))
        return res.sendStatus(400);
      const draft = await store.findOne('onboarding_drafts', { account_id: user.id });
      if (req.body.phase === 'browser-complete' ? !user.onboardingCompleted : !draft)
        return res.sendStatus(409);
      setupRoundTrip = {
        ready: true,
        email: user.email,
        account_id: user.id,
        phase: req.body.phase,
      };
      res.json(setupRoundTrip);
    } catch (error) {
      next(error);
    }
  });
  app.get('/__test/measurement-roundtrip', (req, res) => {
    if (req.get('X-Test-Fixture') !== 'isolated-simulator') return res.sendStatus(403);
    res.json(measurementRoundTrip || { ready: false });
  });
  app.post('/__test/measurement-roundtrip', async (req, res, next) => {
    if (req.get('X-Test-Fixture') !== 'isolated-simulator') return res.sendStatus(403);
    try {
      const user = await store.findOne('users', { email: req.body.email });
      if (!user || !user.email.startsWith('measurement-') || !user.email.endsWith('@exerly.test')) {
        return res.sendStatus(400);
      }
      const row = await store.findOne('measurements', { id: req.body.id, account_id: user.id });
      if (!row || row.type !== 'waist' || row.value !== 80.5) return res.sendStatus(409);
      measurementRoundTrip = { ready: true, email: user.email, id: row.id };
      res.json(measurementRoundTrip);
    } catch (error) {
      next(error);
    }
  });
  app.get('/__test/measurement-account', async (req, res, next) => {
    if (req.get('X-Test-Fixture') !== 'isolated-simulator') return res.sendStatus(403);
    try {
      const users = await store.find('users', {}, { sort: { created_at: -1 } });
      const user = users.find(
        (row) => row.email.startsWith('measurement-') && row.email.endsWith('@exerly.test')
      );
      if (!user) return res.sendStatus(404);
      res.json({ email: user.email });
    } catch (error) {
      next(error);
    }
  });
  app.get('/__test/weight-account', async (req, res, next) => {
    if (req.get('X-Test-Fixture') !== 'isolated-simulator') return res.sendStatus(403);
    try {
      const users = await store.find('users', {}, { sort: { created_at: -1 } });
      const user = users.find(
        (row) => row.email.startsWith('weight-') && row.email.endsWith('@exerly.test')
      );
      if (!user) return res.sendStatus(404);
      res.json({ email: user.email });
    } catch (error) {
      next(error);
    }
  });
  app.get('/__test/weight-roundtrip', (req, res) => {
    if (req.get('X-Test-Fixture') !== 'isolated-simulator') return res.sendStatus(403);
    res.json(weightRoundTrip || { ready: false });
  });
  app.post('/__test/weight-roundtrip', async (req, res, next) => {
    if (req.get('X-Test-Fixture') !== 'isolated-simulator') return res.sendStatus(403);
    try {
      const user = await store.findOne('users', { email: req.body.email });
      if (!user || !user.email.startsWith('weight-') || !user.email.endsWith('@exerly.test'))
        return res.sendStatus(400);
      const row = await store.findOne('weights', { id: req.body.id, account_id: user.id });
      if (!row || row.weight_kg !== 72.8 || row.revision !== 11) return res.sendStatus(409);
      weightRoundTrip = { ready: true, email: user.email, id: row.id, day: row.entry_date };
      res.json(weightRoundTrip);
    } catch (error) {
      next(error);
    }
  });
  app.get('/__test/daily-logs-account', async (req, res, next) => {
    if (req.get('X-Test-Fixture') !== 'isolated-simulator') return res.sendStatus(403);
    try {
      const users = await store.find('users', {}, { sort: { created_at: -1 } });
      const user = users.find(
        (row) => row.email.startsWith('daily-logs-') && row.email.endsWith('@exerly.test')
      );
      if (!user) return res.sendStatus(404);
      res.json({ email: user.email });
    } catch (error) {
      next(error);
    }
  });
  app.get('/__test/daily-logs-roundtrip', (req, res) => {
    if (req.get('X-Test-Fixture') !== 'isolated-simulator') return res.sendStatus(403);
    res.json(dailyLogsRoundTrip || { ready: false });
  });
  app.post('/__test/daily-logs-roundtrip', async (req, res, next) => {
    if (req.get('X-Test-Fixture') !== 'isolated-simulator') return res.sendStatus(403);
    try {
      const user = await store.findOne('users', { email: req.body.email });
      if (!user || !user.email.startsWith('daily-logs-') || !user.email.endsWith('@exerly.test'))
        return res.sendStatus(400);
      const activity = await store.findOne('activities', {
        id: req.body.activityID,
        account_id: user.id,
      });
      const sleep = await store.findOne('sleep', { id: req.body.sleepID, account_id: user.id });
      if (
        !activity ||
        !sleep ||
        activity.duration_min !== 63.25 ||
        activity.calories !== null ||
        activity.revision !== 6 ||
        sleep.hours !== 8.75 ||
        sleep.quality !== 'good' ||
        sleep.revision !== 5
      )
        return res.sendStatus(409);
      dailyLogsRoundTrip = {
        ready: true,
        email: user.email,
        activityID: activity.id,
        sleepID: sleep.id,
        day: activity.entry_date,
      };
      res.json(dailyLogsRoundTrip);
    } catch (error) {
      next(error);
    }
  });
  app.use((req, res, next) => {
    if (
      offline &&
      (req.path.startsWith('/api/') || req.path === '/auth/token' || req.path === '/auth/refresh')
    ) {
      if (disconnect) return req.socket.destroy();
      return res.status(503).json({ message: 'Simulator connection interruption' });
    }
    if (req.path === '/auth/refresh' && req.method === 'POST') {
      try {
        const claims = jwt.verify(
          String(req.get('Authorization') || '').replace(/^Bearer /, ''),
          process.env.JWT_SECRET
        );
        sessionUpgradeAttempts.push({
          email: claims.email,
          operation: req.get('Idempotency-Key') || null,
        });
      } catch {
        /* The real API below rejects invalid credentials. */
      }
      if (dropSessionUpgradeAcknowledgement) {
        const json = res.json.bind(res);
        res.json = (body) => {
          if (res.statusCode < 400) {
            dropSessionUpgradeAcknowledgement = false;
            req.socket.destroy();
            return res;
          }
          return json(body);
        };
      }
    }
    if (dropSetupAcknowledgement && req.path === '/api/onboarding/complete') {
      const json = res.json.bind(res);
      res.json = (body) => {
        if (res.statusCode < 400) {
          dropSetupAcknowledgement = false;
          req.socket.destroy();
          return res;
        }
        return json(body);
      };
    }
    if (
      dropPreferencesAcknowledgement &&
      req.path === '/api/preferences' &&
      req.method === 'PATCH'
    ) {
      const json = res.json.bind(res);
      res.json = (body) => {
        if (res.statusCode < 400) {
          dropPreferencesAcknowledgement = false;
          req.socket.destroy();
          return res;
        }
        return json(body);
      };
    }
    next();
  });
  app.use(createApp());
  const server = app.listen(Number(process.env.EXERLY_FIXTURE_PORT || 39001), '0.0.0.0', () => {
    console.log(`Isolated simulator API listening on ${server.address().port}`);
  });
  const shutdown = () =>
    server.close(async () => {
      await store.disconnect();
      process.exit(0);
    });
  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
