// Shared adapter and default read policy. Deletion markers are retained so an
// offline client cannot resurrect a removed entry. Recovery/sync reads opt in.
//
// PostgreSQL is the database. DB_MODE=local selects the SQLite driver, which
// remains only for the isolated iOS simulator fixture until it moves to
// PostgreSQL; nothing else should use it.
const isLocal = process.env.DB_MODE === 'local' || process.env.DB_MODE === 'sqlite';
const driver = isLocal ? require('./sqlite') : require('./postgres');
const softDeleted = new Set(['food', 'measurements', 'weights', 'activities', 'sleep']);
function active(collection, filter = {}, includeDeleted = false) {
  return softDeleted.has(collection) && !includeDeleted ? { ...filter, deleted_at: null } : filter;
}
function read(method, collection, filter = {}, options = {}) {
  const { includeDeleted = false, ...rest } = options;
  return driver[method](collection, active(collection, filter, includeDeleted), rest);
}
module.exports = {
  ...driver,
  isLocal,
  find: (collection, filter, options) => read('find', collection, filter, options),
  findOne: (collection, filter, options) => read('findOne', collection, filter, options),
  findById: (collection, id) =>
    softDeleted.has(collection)
      ? read('findOne', collection, { id: String(id) })
      : driver.findById(collection, id),
  count: (collection, filter) => driver.count(collection, active(collection, filter)),
  distinct: (collection, field, filter) =>
    driver.distinct(collection, field, active(collection, filter)),
  sumBy: (collection, filter, group, fields) =>
    driver.sumBy(collection, active(collection, filter), group, fields),
  // Conflicts a fresh transaction may resolve: serialization failures and
  // first-insert unique races. SQLite serializes everything, so it has none.
  isRetryable: (error) => (driver.isRetryable ? driver.isRetryable(error) : false),
};
