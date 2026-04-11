// routes/barcode.js — Barcode lookup endpoint (proxies FatSecret + Open Food Facts)

const express = require('express');
const router = express.Router();

let BarcodeCache;

function initModels(barcodeCacheModel) {
  BarcodeCache = barcodeCacheModel;
}

// ---------- Rate Limiting ----------
const rateLimits = new Map();
const RATE_LIMIT = 30; // lookups per hour per user
const RATE_WINDOW = 60 * 60 * 1000; // 1 hour

// Clean up expired entries every 30 minutes
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of rateLimits) {
    if (now - entry.windowStart > RATE_WINDOW) rateLimits.delete(key);
  }
}, 30 * 60 * 1000);

function checkRateLimit(email) {
  const now = Date.now();
  const entry = rateLimits.get(email);
  if (!entry || now - entry.windowStart > RATE_WINDOW) {
    rateLimits.set(email, { windowStart: now, count: 1 });
    return true;
  }
  if (entry.count >= RATE_LIMIT) return false;
  entry.count++;
  return true;
}

// ---------- FatSecret OAuth2 ----------
let fsAccessToken = null;
let fsTokenExpiry = 0;

async function getFatSecretToken() {
  const clientId = process.env.FATSECRET_CLIENT_ID;
  const clientSecret = process.env.FATSECRET_CLIENT_SECRET;
  if (!clientId || !clientSecret) return null;

  if (fsAccessToken && Date.now() < fsTokenExpiry) return fsAccessToken;

  const credentials = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
  const res = await fetch('https://oauth.fatsecret.com/connect/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Authorization': `Basic ${credentials}`
    },
    body: 'grant_type=client_credentials&scope=basic barcode'
  });

  if (!res.ok) return null;
  const data = await res.json();
  fsAccessToken = data.access_token;
  fsTokenExpiry = Date.now() + (data.expires_in - 60) * 1000;
  return fsAccessToken;
}

// ---------- FatSecret Barcode Lookup ----------
async function fetchFromFatSecret(barcode) {
  const token = await getFatSecretToken();
  if (!token) return null;

  // Normalize to GTIN-13
  const gtin13 = barcode.length < 13
    ? '0'.repeat(13 - barcode.length) + barcode
    : barcode;

  const url = new URL('https://platform.fatsecret.com/rest/food/barcode/find-by-id/v2');
  url.searchParams.set('barcode', gtin13);
  url.searchParams.set('format', 'json');
  url.searchParams.set('flag_default_serving', 'true');

  try {
    const res = await fetch(url, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    if (!res.ok) return null;

    const data = await res.json();
    const food = data.food;
    if (!food || !food.food_name) return null;

    const servings = food.servings?.serving;
    const serving = Array.isArray(servings) ? servings[0] : servings;

    return {
      barcode,
      name: food.food_name,
      brand: food.brand_name || null,
      calories: Math.round(parseFloat(serving?.calories || '0')),
      protein: parseFloat(serving?.protein || '0'),
      carbs: parseFloat(serving?.carbohydrate || '0'),
      fat: parseFloat(serving?.fat || '0'),
      fiber: parseFloat(serving?.fiber || '0'),
      sugar: parseFloat(serving?.sugar || '0'),
      serving_size: serving?.serving_description || serving?.metric_serving_amount
        ? `${serving.metric_serving_amount}${serving.metric_serving_unit || 'g'}`
        : '1 serving',
      source: 'fatsecret'
    };
  } catch {
    return null;
  }
}

// ---------- Open Food Facts Barcode Lookup ----------
async function fetchFromOpenFoodFacts(barcode) {
  try {
    const res = await fetch(`https://world.openfoodfacts.org/api/v0/product/${barcode}.json`);
    if (!res.ok) return null;

    const data = await res.json();
    if (data.status !== 1 || !data.product) return null;

    const p = data.product;
    const name = p.product_name || p.product_name_en || '';
    if (!name) return null;

    const n = p.nutriments || {};
    return {
      barcode,
      name,
      brand: p.brands || null,
      calories: Math.round(n['energy-kcal_100g'] || n['energy-kcal'] || 0),
      protein: n.proteins_100g || 0,
      carbs: n.carbohydrates_100g || 0,
      fat: n.fat_100g || 0,
      fiber: n.fiber_100g || 0,
      sugar: n.sugars_100g || 0,
      serving_size: p.serving_size || '100g',
      source: 'openfoodfacts'
    };
  } catch {
    return null;
  }
}

// ---------- POST /barcode-lookup ----------
router.post('/barcode-lookup', async (req, res) => {
  try {
    const { barcode } = req.body;
    if (!barcode || typeof barcode !== 'string' || !/^\d{8,14}$/.test(barcode)) {
      return res.status(400).json({ found: false, message: 'Invalid barcode. Must be 8-14 digits.' });
    }

    if (!checkRateLimit(req.user.email)) {
      return res.status(429).json({ found: false, message: 'Rate limit exceeded. Try again later.' });
    }

    // Check cache first
    const cached = await BarcodeCache.findOne({ barcode });
    if (cached) {
      return res.json({
        found: true,
        food: {
          barcode: cached.barcode,
          name: cached.name,
          brand: cached.brand,
          calories: cached.calories,
          protein: cached.protein,
          carbs: cached.carbs,
          fat: cached.fat,
          fiber: cached.fiber,
          sugar: cached.sugar,
          serving_size: cached.serving_size,
          source: cached.source,
          cached: true
        }
      });
    }

    // Try FatSecret first, then Open Food Facts
    let result = await fetchFromFatSecret(barcode);
    if (!result) {
      result = await fetchFromOpenFoodFacts(barcode);
    }

    if (!result) {
      return res.status(404).json({ found: false, message: 'Product not found in any database' });
    }

    // Cache the result
    await BarcodeCache.findOneAndUpdate(
      { barcode },
      { ...result, fetched_at: new Date(), expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) },
      { upsert: true }
    );

    res.json({ found: true, food: { ...result, cached: false } });
  } catch (err) {
    res.status(500).json({ found: false, message: 'Barcode lookup failed', error: err.message });
  }
});

module.exports = { router, initModels };
