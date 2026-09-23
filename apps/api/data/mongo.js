// MongoDB driver for the storage adapter.
//
// Mongoose models are generated from the same registry the SQLite driver reads,
// so a field added in schema.js exists in both modes without a second edit.

const mongoose = require('mongoose');
const { AsyncLocalStorage } = require('node:async_hooks');
const { collections, JSON_FIELDS, assertCollection, types } = require('./schema');
const { normalizeFilter, normalizeOptions, normalizePatch } = require('./query');

const MONGOOSE_TYPE = {
  [types.str]: String,
  [types.num]: Number,
  [types.bool]: Boolean,
  [types.date]: Date,
  [types.json]: mongoose.Schema.Types.Mixed,
};

const models = {};
const scope = new AsyncLocalStorage();
const sessionOptions = () => ({ session: scope.getStore()?.session });

async function transaction(fn) {
  if (scope.getStore()) return fn();
  const session = await mongoose.startSession();
  try {
    return await session.withTransaction(
      () => scope.run({ session, pending: Promise.resolve() }, fn),
      { readConcern: { level: 'snapshot' }, writeConcern: { w: 'majority' } }
    );
  } finally {
    await session.endSession();
  }
}

function buildModels() {
  for (const [name, def] of Object.entries(collections)) {
    if (models[name]) continue;
    const shape = Object.fromEntries(
      Object.entries(def.fields).map(([field, type]) => [field, { type: MONGOOSE_TYPE[type] }])
    );
    // strict:false would let unknown keys through; keeping it strict means the
    // registry is the single source of truth for what a document can hold.
    // Mixed JSON includes complete mutation receipts. Removing empty objects
    // changes the response on replay and differs from the SQLite contract.
    const schema = new mongoose.Schema(shape, {
      collection: def.collection,
      versionKey: false,
      minimize: false,
    });
    for (const index of def.indexes || []) {
      schema.index(index.keys, { unique: !!index.unique, sparse: !!index.sparse });
    }
    const modelName = `Store_${name}`;
    models[name] = mongoose.models[modelName] || mongoose.model(modelName, schema);
  }
}

async function connect({ uri } = {}) {
  const target = uri || process.env.MONGODB_URI;
  if (!target) throw new Error('MONGODB_URI is required when DB_MODE is not "local"');
  buildModels();
  await mongoose.connect(target);
  // Index builds are backgrounded by default; awaiting them surfaces a unique
  // constraint that existing data violates at boot instead of at first write.
  await Promise.all(Object.values(models).map((m) => m.init()));
  return { driver: 'mongo', target: target.replace(/\/\/[^@]*@/, '//***:***@') };
}

async function disconnect() {
  await mongoose.disconnect();
}

function model(collection) {
  assertCollection(collection);
  if (!models[collection]) buildModels();
  return models[collection];
}

// ---------- document normalization ----------

// Every document leaves the driver with `id` and `_id` as the same string, so
// callers never branch on which driver produced it.
function fromDoc(doc) {
  if (!doc) return null;
  const source = typeof doc.toObject === 'function' ? doc.toObject() : doc;
  const id = source._id ? String(source._id) : undefined;
  return { ...source, id, _id: id };
}

const OP_MONGO = { ne: '$ne', gt: '$gt', gte: '$gte', lt: '$lt', lte: '$lte' };

function compileFilter(collection, filter) {
  const clauses = normalizeFilter(filter);
  const out = {};

  for (const { field, op, value } of clauses) {
    const key = field === 'id' ? '_id' : field;
    const encoded = key === '_id' ? toObjectId(value) : value;

    if (op === 'eq') {
      out[key] = out[key] ? { ...out[key], $eq: encoded } : encoded;
    } else if (op === 'in' || op === 'nin') {
      const list = key === '_id' ? value.map(toObjectId) : value;
      out[key] = { ...(typeof out[key] === 'object' ? out[key] : {}), [`$${op}`]: list };
    } else if (op === 'like') {
      // Escape the needle so a user-supplied search string is matched literally
      // rather than compiled as a regex.
      const safe = String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      out[key] = new RegExp(safe, 'i');
    } else if (op === 'exists') {
      out[key] = { ...(typeof out[key] === 'object' ? out[key] : {}), $exists: value };
    } else {
      out[key] = { ...(typeof out[key] === 'object' ? out[key] : {}), [OP_MONGO[op]]: encoded };
    }
  }
  return out;
}

// An id that isn't a valid ObjectId must not match anything. Returning a
// sentinel keeps "not found" a 404 instead of a 500 CastError.
const NO_MATCH = new mongoose.Types.ObjectId('000000000000000000000000');
function toObjectId(value) {
  if (value instanceof mongoose.Types.ObjectId) return value;
  const s = String(value);
  return mongoose.Types.ObjectId.isValid(s) ? new mongoose.Types.ObjectId(s) : NO_MATCH;
}

function compileOptions(options) {
  const { sort, limit, skip } = normalizeOptions(options);
  const sortSpec = {};
  for (const s of sort) sortSpec[s.field === 'id' ? '_id' : s.field] = s.dir;
  return { sortSpec, limit, skip };
}

// ---------- operations ----------

async function insert(collection, doc) {
  const [created] = await model(collection).create([doc], sessionOptions());
  return fromDoc(created);
}

async function find(collection, filter = {}, options = {}) {
  const { sortSpec, limit, skip } = compileOptions(options);
  let q = model(collection).find(compileFilter(collection, filter), null, sessionOptions());
  if (Object.keys(sortSpec).length) q = q.sort(sortSpec);
  if (skip) q = q.skip(skip);
  if (limit != null) q = q.limit(limit);
  const docs = await q.lean();
  return docs.map(fromDoc);
}

async function findOne(collection, filter = {}, options = {}) {
  const rows = await find(collection, filter, { ...options, limit: 1 });
  return rows[0] || null;
}

async function findById(collection, id) {
  return findOne(collection, { id: String(id) });
}

async function update(collection, filter, patch) {
  const clean = normalizePatch(patch, JSON_FIELDS[collection]);
  const doc = await model(collection)
    .findOneAndUpdate(
      compileFilter(collection, filter),
      { $set: clean },
      { new: true, ...sessionOptions() }
    )
    .lean();
  return fromDoc(doc);
}

async function updateMany(collection, filter, patch) {
  const clean = normalizePatch(patch, JSON_FIELDS[collection]);
  const res = await model(collection).updateMany(
    compileFilter(collection, filter),
    {
      $set: clean,
    },
    sessionOptions()
  );
  return res.modifiedCount || 0;
}

async function upsert(collection, filter, patch) {
  const clean = normalizePatch(patch, JSON_FIELDS[collection]);
  // Equality clauses go in $setOnInsert so a newly created document carries the
  // keys it was looked up by, matching the SQLite driver's seeding behaviour.
  const seed = {};
  for (const { field, op, value } of normalizeFilter(filter)) {
    if (op === 'eq' && field !== 'id' && field !== '_id' && !(field in clean)) {
      seed[field] = value;
    }
  }
  const write = { $set: clean };
  if (Object.keys(seed).length) write.$setOnInsert = seed;

  const doc = await model(collection)
    .findOneAndUpdate(compileFilter(collection, filter), write, {
      new: true,
      upsert: true,
      ...sessionOptions(),
    })
    .lean();
  return fromDoc(doc);
}

async function increment(collection, filter, field, amount) {
  assertCollection(collection);
  const seed = {};
  for (const { field: f, op, value } of normalizeFilter(filter)) {
    if (op === 'eq' && f !== 'id' && f !== '_id') seed[f] = value;
  }
  const write = { $inc: { [field]: Number(amount || 0) } };
  if (Object.keys(seed).length) write.$setOnInsert = seed;

  const doc = await model(collection)
    .findOneAndUpdate(compileFilter(collection, filter), write, {
      new: true,
      upsert: true,
      ...sessionOptions(),
    })
    .lean();
  return fromDoc(doc);
}

async function removeOne(collection, filter) {
  const doc = await model(collection)
    .findOneAndDelete(compileFilter(collection, filter), sessionOptions())
    .lean();
  return fromDoc(doc);
}

async function remove(collection, filter) {
  const res = await model(collection).deleteMany(
    compileFilter(collection, filter),
    sessionOptions()
  );
  return res.deletedCount || 0;
}

async function count(collection, filter = {}) {
  return model(collection).countDocuments(compileFilter(collection, filter), sessionOptions());
}

async function distinct(collection, field, filter = {}) {
  const def = assertCollection(collection);
  if (!(field in def.fields)) throw new Error(`Unknown field ${collection}.${field}`);
  const values = await model(collection)
    .distinct(field, compileFilter(collection, filter))
    .session(scope.getStore()?.session || null);
  return values.filter((v) => v != null);
}

async function sumBy(collection, filter, groupField, sumFields) {
  const def = assertCollection(collection);
  const fields = Array.isArray(sumFields) ? sumFields : [sumFields];
  if (!(groupField in def.fields)) throw new Error(`Unknown field ${collection}.${groupField}`);
  fields.forEach((f) => {
    if (!(f in def.fields)) throw new Error(`Unknown field ${collection}.${f}`);
  });

  const group = { _id: `$${groupField}`, n: { $sum: 1 } };
  fields.forEach((f) => (group[f] = { $sum: `$${f}` }));

  const rows = await model(collection)
    .aggregate([{ $match: compileFilter(collection, filter) }, { $group: group }])
    .session(scope.getStore()?.session || null);

  return rows.map((r) => {
    const out = { key: r._id, n: r.n };
    fields.forEach((f) => (out[f] = Number(r[f]) || 0));
    return out;
  });
}

module.exports = {
  name: 'mongo',
  connect,
  disconnect,
  isReady: () => mongoose.connection.readyState === 1,
  connection: () => mongoose.connection,
  insert,
  find,
  findOne,
  findById,
  update,
  updateMany,
  upsert,
  increment,
  remove,
  removeOne,
  count,
  distinct,
  sumBy,
  transaction,
};

// MongoDB sessions do not support concurrent operations inside a transaction.
// Existing route code can still gather independent reads with Promise.all.
for (const name of [
  'insert',
  'find',
  'findOne',
  'findById',
  'update',
  'updateMany',
  'upsert',
  'increment',
  'remove',
  'removeOne',
  'count',
  'distinct',
  'sumBy',
]) {
  const operation = module.exports[name];
  module.exports[name] = (...args) => {
    const context = scope.getStore();
    if (!context) return operation(...args);
    const result = context.pending.then(() => operation(...args));
    context.pending = result.catch(() => {});
    return result;
  };
}
