// SQLite driver for the storage adapter.
//
// Used when DB_MODE=local (offline development) and by the integration test
// suite, where an in-memory database gives every test file a clean server in a
// few milliseconds.

const sqlite3 = require('sqlite3');
const { AsyncLocalStorage } = require('node:async_hooks');
const { collections, JSON_FIELDS, assertCollection, types } = require('./schema');
const { normalizeFilter, normalizeOptions, normalizePatch } = require('./query');

const SQL_TYPE = {
  [types.str]: 'TEXT',
  [types.num]: 'REAL',
  [types.bool]: 'INTEGER',
  [types.date]: 'TEXT',
  [types.json]: 'TEXT',
};

let db = null;
const scope = new AsyncLocalStorage();
let pending = Promise.resolve();

// A shared SQLite connection must never let an unrelated request join a
// transaction. Serialize complete operations, including read-modify-write.
function exclusive(fn) {
  if (scope.getStore()) return fn();
  const result = pending.then(() => scope.run({ transaction: false }, fn));
  pending = result.catch(() => {});
  return result;
}

async function transaction(fn) {
  if (scope.getStore()?.transaction) return fn();
  return exclusive(() =>
    scope.run({ transaction: true }, async () => {
      await run('BEGIN IMMEDIATE');
      try {
        const result = await fn();
        await run('COMMIT');
        return result;
      } catch (error) {
        await run('ROLLBACK');
        throw error;
      }
    })
  );
}

function run(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.run(sql, params, function (err) {
      if (err) reject(err);
      else resolve({ changes: this.changes, lastID: this.lastID });
    });
  });
}

function all(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.all(sql, params, (err, rows) => {
      if (err) reject(err);
      else resolve(rows || []);
    });
  });
}

async function connect({ file } = {}) {
  const target = file || process.env.SQLITE_FILE || './fitness-local.db';
  await new Promise((resolve, reject) => {
    db = new sqlite3.Database(target, (err) => (err ? reject(err) : resolve()));
  });
  await run('PRAGMA foreign_keys = ON');
  await run('PRAGMA busy_timeout = 5000');
  await transaction(migrate);
  return { driver: 'sqlite', target };
}

function columnsSql(def) {
  return Object.entries(def.fields)
    .map(([field, type]) => `${field} ${SQL_TYPE[type]}`)
    .join(', ');
}

// CREATE TABLE for anything missing, then ALTER TABLE ADD COLUMN for fields
// added to the registry since the file was created. SQLite has no DROP COLUMN
// worth using, so removed fields are left in place and ignored.
async function migrate() {
  for (const [name, def] of Object.entries(collections)) {
    await run(
      `CREATE TABLE IF NOT EXISTS ${name} (id INTEGER PRIMARY KEY AUTOINCREMENT, ${columnsSql(def)})`
    );

    const info = await all(`PRAGMA table_info(${name})`);
    if (needsRebuild(info)) {
      await rebuild(name, def, info);
      continue;
    }

    const existing = new Set(info.map((c) => c.name));
    for (const [field, type] of Object.entries(def.fields)) {
      if (!existing.has(field)) {
        await run(`ALTER TABLE ${name} ADD COLUMN ${field} ${SQL_TYPE[type]}`);
      }
    }

    await ensureIndexes(name, def);
  }

  await convertLegacyWaterGlasses();
}

async function ensureIndexes(name, def) {
  for (const [i, index] of (def.indexes || []).entries()) {
    const cols = Object.keys(index.keys).join(', ');
    const unique = index.unique ? 'UNIQUE' : '';
    await run(`CREATE ${unique} INDEX IF NOT EXISTS idx_${name}_${i} ON ${name} (${cols})`);
  }
}

// Tables this file creates never declare NOT NULL on anything but the primary
// key. A NOT NULL column therefore means the table predates the storage adapter
// (the old server-local.js declared things like `food.sugar REAL NOT NULL`) and
// would reject rows the current code writes.
function needsRebuild(info) {
  return info.some((c) => c.notnull === 1 && c.name !== 'id');
}

// SQLite can't relax a constraint in place, so the table is rebuilt: copy the
// columns both schemas share into a fresh table and swap it in.
async function rebuild(name, def, info) {
  const shared = info.map((c) => c.name).filter((c) => c === 'id' || c in def.fields);
  const temp = `${name}__migrating`;

  await run(`DROP TABLE IF EXISTS ${temp}`);
  await run(`CREATE TABLE ${temp} (id INTEGER PRIMARY KEY AUTOINCREMENT, ${columnsSql(def)})`);
  if (shared.length) {
    await run(
      `INSERT INTO ${temp} (${shared.join(', ')}) SELECT ${shared.join(', ')} FROM ${name}`
    );
  }
  await run(`DROP TABLE ${name}`);
  await run(`ALTER TABLE ${temp} RENAME TO ${name}`);
  await ensureIndexes(name, def);
}

// Water used to be counted in 250ml "glasses". Any legacy rows are converted
// once so the history survives the change of unit.
async function convertLegacyWaterGlasses() {
  const columns = (await all(`PRAGMA table_info(water)`)).map((c) => c.name);
  if (!columns.includes('glasses')) return;
  await run('UPDATE water SET ml = glasses * 250 WHERE ml IS NULL AND glasses IS NOT NULL');
}

async function disconnect() {
  if (!db) return;
  await new Promise((resolve) => db.close(() => resolve()));
  db = null;
}

// ---------- row <-> document ----------

function toColumn(collection, field, value) {
  const def = assertCollection(collection);
  const type = def.fields[field];
  if (value === undefined) return undefined;
  if (value === null) return null;
  if (type === types.json) return JSON.stringify(value);
  if (type === types.bool) return value ? 1 : 0;
  if (type === types.date) return value instanceof Date ? value.toISOString() : String(value);
  if (type === types.num) return Number(value);
  if (type === types.str) return String(value);
  return value;
}

function fromRow(collection, row) {
  if (!row) return null;
  const def = assertCollection(collection);
  const doc = {};
  for (const [field, type] of Object.entries(def.fields)) {
    const raw = row[field];
    if (raw === undefined) continue;
    if (raw === null) {
      doc[field] = null;
    } else if (type === types.json) {
      try {
        doc[field] = JSON.parse(raw);
      } catch {
        doc[field] = null;
      }
    } else if (type === types.bool) {
      doc[field] = !!raw;
    } else if (type === types.date) {
      const d = new Date(raw);
      doc[field] = Number.isNaN(d.getTime()) ? null : d;
    } else {
      doc[field] = raw;
    }
  }
  // Both keys are populated so callers (and the iOS client, which reads `_id`)
  // see the same shape they get from the Mongo driver.
  doc.id = String(row.id);
  doc._id = String(row.id);
  return doc;
}

// ---------- filter compilation ----------

const OP_SQL = { eq: '=', ne: '!=', gt: '>', gte: '>=', lt: '<', lte: '<=' };

function compileFilter(collection, filter) {
  const clauses = normalizeFilter(filter);
  const parts = [];
  const params = [];

  for (const { field, op, value } of clauses) {
    const column = field === '_id' || field === 'id' ? 'id' : field;
    const encode = (v) =>
      column === 'id' ? Number(v) : toColumn(collection, field, v instanceof Date ? v : v);

    if (op === 'in' || op === 'nin') {
      if (value.length === 0) {
        parts.push(op === 'in' ? '0 = 1' : '1 = 1');
        continue;
      }
      const holes = value.map(() => '?').join(', ');
      parts.push(`${column} ${op === 'in' ? 'IN' : 'NOT IN'} (${holes})`);
      params.push(...value.map(encode));
    } else if (op === 'like') {
      parts.push(`LOWER(${column}) LIKE ?`);
      params.push(`%${String(value).toLowerCase()}%`);
    } else if (op === 'exists') {
      parts.push(value ? `${column} IS NOT NULL` : `${column} IS NULL`);
    } else if (value === null) {
      parts.push(op === 'ne' ? `${column} IS NOT NULL` : `${column} IS NULL`);
    } else {
      parts.push(`${column} ${OP_SQL[op]} ?`);
      params.push(encode(value));
    }
  }

  return { where: parts.length ? `WHERE ${parts.join(' AND ')}` : '', params };
}

function compileOptions(options) {
  const { sort, limit, skip } = normalizeOptions(options);
  const orderBy = sort.length
    ? `ORDER BY ${sort.map((s) => `${s.field === '_id' ? 'id' : s.field} ${s.dir < 0 ? 'DESC' : 'ASC'}`).join(', ')}`
    : '';
  // SQLite requires a LIMIT before it will honour OFFSET.
  const limitSql = limit != null ? `LIMIT ${limit}` : skip ? 'LIMIT -1' : '';
  const offsetSql = skip ? `OFFSET ${skip}` : '';
  return [orderBy, limitSql, offsetSql].filter(Boolean).join(' ');
}

// ---------- operations ----------

async function insert(collection, doc) {
  const def = assertCollection(collection);
  const fields = Object.keys(doc).filter((f) => f in def.fields && doc[f] !== undefined);
  if (fields.length === 0) throw new Error(`insert(${collection}) had no known fields`);
  const holes = fields.map(() => '?').join(', ');
  const params = fields.map((f) => toColumn(collection, f, doc[f]));
  const { lastID } = await run(
    `INSERT INTO ${collection} (${fields.join(', ')}) VALUES (${holes})`,
    params
  );
  return findById(collection, lastID);
}

async function findById(collection, id) {
  assertCollection(collection);
  const rows = await all(`SELECT * FROM ${collection} WHERE id = ?`, [Number(id)]);
  return fromRow(collection, rows[0]);
}

async function find(collection, filter = {}, options = {}) {
  assertCollection(collection);
  const { where, params } = compileFilter(collection, filter);
  const rows = await all(
    `SELECT * FROM ${collection} ${where} ${compileOptions(options)}`.trim(),
    params
  );
  return rows.map((r) => fromRow(collection, r));
}

async function findOne(collection, filter = {}, options = {}) {
  const rows = await find(collection, filter, { ...options, limit: 1 });
  return rows[0] || null;
}

async function update(collection, filter, patch) {
  const def = assertCollection(collection);
  const clean = normalizePatch(patch, JSON_FIELDS[collection]);
  const fields = Object.keys(clean).filter((f) => f in def.fields);
  const existing = await findOne(collection, filter);
  if (!existing) return null;
  if (fields.length === 0) return existing;

  const sets = fields.map((f) => `${f} = ?`).join(', ');
  const params = fields.map((f) => toColumn(collection, f, clean[f]));
  const compiled = compileFilter(collection, { ...filter, id: existing.id });
  const { changes } = await run(`UPDATE ${collection} SET ${sets} ${compiled.where}`, [
    ...params,
    ...compiled.params,
  ]);
  if (!changes) return null;
  return findById(collection, existing.id);
}

async function updateMany(collection, filter, patch) {
  const def = assertCollection(collection);
  const clean = normalizePatch(patch, JSON_FIELDS[collection]);
  const fields = Object.keys(clean).filter((f) => f in def.fields);
  if (fields.length === 0) return 0;
  const { where, params } = compileFilter(collection, filter);
  const sets = fields.map((f) => `${f} = ?`).join(', ');
  const setParams = fields.map((f) => toColumn(collection, f, clean[f]));
  const { changes } = await run(
    `UPDATE ${collection} SET ${sets} ${where}`.trim(),
    setParams.concat(params)
  );
  return changes;
}

async function upsert(collection, filter, patch) {
  const existing = await findOne(collection, filter);
  if (existing) return update(collection, { id: existing.id }, patch);
  // The filter's equality clauses seed the new row so an upsert keyed on
  // {email, entry_date} produces a row that the same filter will find again.
  const seed = {};
  for (const { field, op, value } of normalizeFilter(filter)) {
    if (op === 'eq' && field !== 'id' && field !== '_id') seed[field] = value;
  }
  return insert(collection, { ...seed, ...patch });
}

async function increment(collection, filter, field, amount) {
  const def = assertCollection(collection);
  if (!(field in def.fields)) throw new Error(`Unknown field ${collection}.${field}`);
  const existing = await findOne(collection, filter);
  const current = existing ? Number(existing[field]) || 0 : 0;
  const next = current + Number(amount || 0);
  return upsert(collection, filter, { [field]: next });
}

async function removeOne(collection, filter) {
  const existing = await findOne(collection, filter);
  if (!existing) return null;
  await run(`DELETE FROM ${collection} WHERE id = ?`, [Number(existing.id)]);
  return existing;
}

async function remove(collection, filter) {
  assertCollection(collection);
  const { where, params } = compileFilter(collection, filter);
  const { changes } = await run(`DELETE FROM ${collection} ${where}`.trim(), params);
  return changes;
}

async function count(collection, filter = {}) {
  assertCollection(collection);
  const { where, params } = compileFilter(collection, filter);
  const rows = await all(`SELECT COUNT(*) AS n FROM ${collection} ${where}`.trim(), params);
  return rows[0]?.n || 0;
}

async function distinct(collection, field, filter = {}) {
  const def = assertCollection(collection);
  if (!(field in def.fields)) throw new Error(`Unknown field ${collection}.${field}`);
  const { where, params } = compileFilter(collection, filter);
  const rows = await all(
    `SELECT DISTINCT ${field} AS v FROM ${collection} ${where}`.trim(),
    params
  );
  return rows.map((r) => r.v).filter((v) => v != null);
}

// SUM(field) per distinct value of groupField. Returns [{ key, <field>: total }].
async function sumBy(collection, filter, groupField, sumFields) {
  const def = assertCollection(collection);
  const fields = Array.isArray(sumFields) ? sumFields : [sumFields];
  if (!(groupField in def.fields)) throw new Error(`Unknown field ${collection}.${groupField}`);
  fields.forEach((f) => {
    if (!(f in def.fields)) throw new Error(`Unknown field ${collection}.${f}`);
  });

  const { where, params } = compileFilter(collection, filter);
  const sums = fields.map((f) => `COALESCE(SUM(${f}), 0) AS ${f}`).join(', ');
  const rows = await all(
    `SELECT ${groupField} AS key, ${sums}, COUNT(*) AS n FROM ${collection} ${where} GROUP BY ${groupField}`.trim(),
    params
  );
  return rows.map((r) => {
    const out = { key: r.key, n: r.n };
    fields.forEach((f) => (out[f] = Number(r[f]) || 0));
    return out;
  });
}

module.exports = {
  name: 'sqlite',
  connect,
  disconnect,
  isReady: () => db != null,
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
  module.exports[name] = (...args) => exclusive(() => operation(...args));
}
