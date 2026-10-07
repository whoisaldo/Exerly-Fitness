// Filter grammar shared by both drivers.
//
// Callers write plain objects. Everything is normalized into a flat list of
// {field, op, value} before it reaches a driver, which means a value arriving
// from req.body or req.query can never be interpreted as an operator. That is
// the NoSQL-injection guard: `{ email: { $ne: null } }` from a client body is
// rejected here rather than reaching Mongo.

const OPS = new Set(['eq', 'ne', 'in', 'nin', 'gt', 'gte', 'lt', 'lte', 'like', 'exists']);

const FIELD_RE = /^[A-Za-z_][A-Za-z0-9_]*$/;

function isPlainObject(v) {
  return v !== null && typeof v === 'object' && !Array.isArray(v) && !(v instanceof Date);
}

// Reject anything that isn't a primitive, a Date, or an array of those.
function assertValue(field, op, value) {
  if (op === 'in' || op === 'nin') {
    if (!Array.isArray(value)) throw new Error(`Filter ${field}.${op} expects an array`);
    value.forEach((v) => assertScalar(field, v));
    return value;
  }
  if (op === 'exists') {
    if (typeof value !== 'boolean') throw new Error(`Filter ${field}.exists expects a boolean`);
    return value;
  }
  assertScalar(field, value);
  return value;
}

function assertScalar(field, value) {
  if (value === null) return;
  const type = typeof value;
  if (type === 'string' || type === 'number' || type === 'boolean') return;
  if (value instanceof Date) return;
  throw new Error(`Filter on "${field}" got an unsupported value type`);
}

// { email: 'a@b.c', entry_date: { gte: '2026-01-01' } }
//   -> [{field:'email',op:'eq',...}, {field:'entry_date',op:'gte',...}]
function normalizeFilter(filter = {}) {
  if (!isPlainObject(filter)) throw new Error('Filter must be an object');

  const clauses = [];
  for (const [field, raw] of Object.entries(filter)) {
    if (!FIELD_RE.test(field) && field !== '_id' && field !== 'id') {
      throw new Error(`Invalid filter field: ${field}`);
    }
    if (isPlainObject(raw)) {
      for (const [op, value] of Object.entries(raw)) {
        if (!OPS.has(op)) throw new Error(`Unsupported filter operator: ${op}`);
        clauses.push({ field, op, value: assertValue(field, op, value) });
      }
    } else {
      clauses.push({ field, op: 'eq', value: assertValue(field, 'eq', raw) });
    }
  }
  return clauses;
}

// { sort: { created_at: -1 }, limit, skip }
function normalizeOptions(options = {}) {
  const sort = [];
  if (options.sort) {
    if (!isPlainObject(options.sort)) throw new Error('sort must be an object');
    for (const [field, dir] of Object.entries(options.sort)) {
      if (!FIELD_RE.test(field) && field !== '_id' && field !== 'id') {
        throw new Error(`Invalid sort field: ${field}`);
      }
      sort.push({ field, dir: Number(dir) < 0 ? -1 : 1 });
    }
  }

  const limit = options.limit == null ? null : Math.max(0, Math.floor(Number(options.limit) || 0));
  const skip = options.skip == null ? 0 : Math.max(0, Math.floor(Number(options.skip) || 0));

  return { sort, limit, skip };
}

// Patches go through the same treatment so a request body can't smuggle in
// `$rename` or `$unset`. JSON-typed fields are the one place objects are legal.
function normalizePatch(patch = {}, jsonFields = []) {
  if (!isPlainObject(patch)) throw new Error('Patch must be an object');
  const out = {};
  for (const [field, value] of Object.entries(patch)) {
    if (!FIELD_RE.test(field)) throw new Error(`Invalid patch field: ${field}`);
    if (jsonFields.includes(field)) {
      out[field] = value;
      continue;
    }
    if (isPlainObject(value)) throw new Error(`Patch field "${field}" cannot be an object`);
    if (Array.isArray(value)) throw new Error(`Patch field "${field}" cannot be an array`);
    out[field] = value;
  }
  return out;
}

module.exports = { OPS, normalizeFilter, normalizeOptions, normalizePatch, isPlainObject };
