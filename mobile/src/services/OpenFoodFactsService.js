import AsyncStorage from '@react-native-async-storage/async-storage';

const BASE_URL = 'https://world.openfoodfacts.org';
const BARCODE_CACHE_KEY = 'food_barcode_cache';
const MAX_BARCODE_CACHE = 50;
const SEARCH_CACHE_TTL = 5 * 60 * 1000;

const searchCache = new Map();

/**
 * Normalize raw OFF product into standard FoodItem shape.
 * All nutriment values are per 100g.
 */
export function normalizeProduct(raw) {
  const n = raw.nutriments ?? {};
  const name = (raw.product_name ?? 'Unknown').trim();

  return {
    id: raw.code ?? raw._id ?? `off_${Date.now()}`,
    name: name.charAt(0).toUpperCase() + name.slice(1),
    brand: raw.brands?.split(',')[0]?.trim() ?? null,
    calories: Math.round(n['energy-kcal_100g'] ?? n['energy-kcal'] ?? 0),
    protein: Math.round((n.proteins_100g ?? 0) * 10) / 10,
    carbs: Math.round((n.carbohydrates_100g ?? 0) * 10) / 10,
    fat: Math.round((n.fat_100g ?? 0) * 10) / 10,
    sugar: Math.round((n.sugars_100g ?? 0) * 10) / 10,
    fiber: Math.round((n.fiber_100g ?? 0) * 10) / 10,
    sodium: Math.round((n.sodium_100g ?? 0) * 1000),
    saturatedFat: Math.round((n['saturated-fat_100g'] ?? 0) * 10) / 10,
    servingSize: raw.serving_size ?? '100g',
    servingGrams: parseServingGrams(raw.serving_size),
    imageUrl: raw.image_url ?? raw.image_front_small_url ?? null,
    source: 'openfoodfacts',
    barcode: raw.code ?? null,
    categories: raw.categories ?? '',
  };
}

function parseServingGrams(str) {
  if (!str) return 100;
  const match = str.match(/(\d+\.?\d*)\s*g/i);
  return match ? parseFloat(match[1]) : 100;
}

/**
 * Search foods via Open Food Facts API.
 */
export async function searchFoods(query, page = 1) {
  if (!query || query.length < 2) {
    return { products: [], total: 0, page, pageSize: 25 };
  }

  const cacheKey = `${query.toLowerCase()}_${page}`;
  const cached = searchCache.get(cacheKey);

  if (cached && Date.now() - cached.timestamp < SEARCH_CACHE_TTL) {
    refreshSearchInBackground(query, page, cacheKey);
    return cached.results;
  }

  try {
    const params = new URLSearchParams({
      search_terms: query,
      search_simple: '1',
      action: 'process',
      json: '1',
      page_size: '25',
      page: String(page),
      fields: 'code,product_name,brands,nutriments,image_url,serving_size,quantity,categories',
    });

    const res = await fetch(`${BASE_URL}/cgi/search.pl?${params}`, {
      signal: AbortSignal.timeout(10000),
    });

    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const json = await res.json();

    const products = (json.products ?? [])
      .filter((p) => p.product_name)
      .map(normalizeProduct);

    const result = {
      products,
      total: json.count ?? 0,
      page: json.page ?? page,
      pageSize: 25,
    };

    searchCache.set(cacheKey, { results: result, timestamp: Date.now() });
    return result;
  } catch (err) {
    if (cached) return cached.results;
    throw err;
  }
}

function refreshSearchInBackground(query, page, cacheKey) {
  const params = new URLSearchParams({
    search_terms: query,
    search_simple: '1',
    action: 'process',
    json: '1',
    page_size: '25',
    page: String(page),
    fields: 'code,product_name,brands,nutriments,image_url,serving_size,quantity,categories',
  });

  fetch(`${BASE_URL}/cgi/search.pl?${params}`)
    .then((r) => r.json())
    .then((json) => {
      const products = (json.products ?? [])
        .filter((p) => p.product_name)
        .map(normalizeProduct);

      searchCache.set(cacheKey, {
        results: { products, total: json.count ?? 0, page, pageSize: 25 },
        timestamp: Date.now(),
      });
    })
    .catch(() => {});
}

/**
 * Fetch a single product by barcode.
 */
export async function fetchByBarcode(barcode) {
  const cached = await getBarcodeCached(barcode);
  if (cached) return cached;

  const res = await fetch(
    `${BASE_URL}/api/v0/product/${barcode}.json`,
    { signal: AbortSignal.timeout(10000) },
  );

  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const json = await res.json();

  if (json.status !== 1 || !json.product) return null;

  const product = normalizeProduct(json.product);
  await addToBarcodeCache(barcode, product);
  return product;
}

async function getBarcodeCached(barcode) {
  try {
    const raw = await AsyncStorage.getItem(BARCODE_CACHE_KEY);
    if (!raw) return null;
    const cache = JSON.parse(raw);
    return cache[barcode] ?? null;
  } catch {
    return null;
  }
}

async function addToBarcodeCache(barcode, product) {
  try {
    const raw = await AsyncStorage.getItem(BARCODE_CACHE_KEY);
    const cache = raw ? JSON.parse(raw) : {};
    cache[barcode] = product;
    const keys = Object.keys(cache);
    if (keys.length > MAX_BARCODE_CACHE) {
      delete cache[keys[0]];
    }
    await AsyncStorage.setItem(BARCODE_CACHE_KEY, JSON.stringify(cache));
  } catch {}
}

export class ProductNotFoundError extends Error {
  constructor(barcode) {
    super(`Product not found: ${barcode}`);
    this.name = 'ProductNotFoundError';
    this.barcode = barcode;
  }
}
