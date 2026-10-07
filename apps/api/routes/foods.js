// Food search and barcode lookup for ExerlyCore. Results are Foods in the
// `saved_food` document shape, ready to save or log, from Open Food Facts.
// Personal tokens can use these too: searching reads no account data.

const express = require('express');
const { authenticate } = require('../lib/auth');
const { ApiError, asyncHandler, badRequest, notFound, tooMany } = require('../lib/errors');
const v = require('../lib/validate');
const providers = require('../lib/foodProviders');
const { normalizeBarcode } = require('../lib/barcodes');
const coreFoods = require('../lib/coreFoods');

const router = express.Router();
router.use(authenticate);

const unavailable = () =>
  new ApiError(503, 'The food database is unavailable right now. Try again shortly.');

router.get(
  '/search',
  asyncHandler(
    async (req, res) => {
      const query = v.str(req.query.q, 'q', { max: 100 });
      if (query.length < 2) throw badRequest('q needs at least two characters');
      const limit = v.int(req.query.limit ?? 20, 'limit', { min: 1, max: 50 });
      const products = await providers.searchOpenFoodFactsProducts(query, limit);
      res.json({
        foods: products.map((product) => coreFoods.fromOpenFoodFacts(product)).filter(Boolean),
        attribution: coreFoods.ATTRIBUTION.openFoodFacts,
      });
    },
    { transactional: false }
  )
);

router.get(
  '/barcode/:code',
  asyncHandler(
    async (req, res) => {
      const identity = normalizeBarcode(req.params.code, req.query.symbology);
      if (identity.status !== 'valid') throw badRequest(identity.message);
      const result = await providers.openFoodFactsBarcode(identity, {});
      if (result.status === 'not_found') throw notFound('No food has that barcode');
      if (result.status === 'rate_limited') {
        res.set('Retry-After', String(result.retry_after ?? 60));
        throw tooMany('Food lookups are busy. Try again shortly.');
      }
      const food =
        result.status === 'found'
          ? coreFoods.fromOpenFoodFacts({
              ...result.product,
              code: result.product.code || identity.openFoodFacts,
            })
          : null;
      if (!food) throw unavailable();
      res.json({ food, attribution: coreFoods.ATTRIBUTION.openFoodFacts });
    },
    { transactional: false }
  )
);

module.exports = router;
