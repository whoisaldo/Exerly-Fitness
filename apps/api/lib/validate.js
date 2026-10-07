// Input validation. Small and explicit rather than a schema library, because
// the shapes are simple and one more dependency isn't worth it here.

const { badRequest } = require('./errors');
const { isValidDateStr } = require('./dates');

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function str(value, field, { required = true, max = 500, min = 1, trim = true } = {}) {
  if (value == null || value === '') {
    if (required) throw badRequest(`${field} is required`);
    return null;
  }
  if (typeof value !== 'string') throw badRequest(`${field} must be text`);
  const out = trim ? value.trim() : value;
  if (out.length < min) throw badRequest(`${field} is required`);
  if (out.length > max) throw badRequest(`${field} must be ${max} characters or fewer`);
  return out;
}

function num(value, field, { required = true, min = -Infinity, max = Infinity } = {}) {
  if (value == null || value === '') {
    if (required) throw badRequest(`${field} is required`);
    return null;
  }
  if (typeof value !== 'number' && typeof value !== 'string')
    throw badRequest(`${field} must be a number`);
  if (typeof value === 'string' && !value.trim()) throw badRequest(`${field} must be a number`);
  const n = Number(value);
  if (!Number.isFinite(n)) throw badRequest(`${field} must be a number`);
  if (n < min) throw badRequest(`${field} must be at least ${min}`);
  if (n > max) throw badRequest(`${field} must be at most ${max}`);
  return n;
}

function int(value, field, opts = {}) {
  const n = num(value, field, opts);
  if (n != null && !Number.isInteger(n)) throw badRequest(`${field} must be a whole number`);
  return n;
}

function bool(value, field, { required = false } = {}) {
  if (value == null) {
    if (required) throw badRequest(`${field} is required`);
    return null;
  }
  if (typeof value === 'boolean') return value;
  if (value === 'true' || value === 1 || value === '1') return true;
  if (value === 'false' || value === 0 || value === '0') return false;
  throw badRequest(`${field} must be true or false`);
}

// Matching is case-insensitive and returns the canonical value from `allowed`.
// The deployed iOS app and the older web food page both send meal types as
// "Snack" rather than "snack", so a case-sensitive check would have started
// rejecting food logs from every existing client.
function oneOf(value, field, allowed, { required = true } = {}) {
  if (value == null || value === '') {
    if (required) throw badRequest(`${field} is required`);
    return null;
  }
  const needle = String(value).trim().toLowerCase();
  const match = allowed.find((option) => option.toLowerCase() === needle);
  if (!match) {
    throw badRequest(`${field} must be one of: ${allowed.join(', ')}`);
  }
  return match;
}

function email(value, field = 'email') {
  const v = str(value, field, { max: 254 });
  if (!EMAIL_RE.test(v)) throw badRequest('Invalid email format');
  return v.toLowerCase();
}

function dateStr(value, field, { required = true } = {}) {
  if (value == null || value === '') {
    if (required) throw badRequest(`${field} is required`);
    return null;
  }
  if (!isValidDateStr(value)) throw badRequest(`${field} must be a YYYY-MM-DD date`);
  return value;
}

// Passwords: length is the only rule that reliably helps. Composition rules
// push people toward "Password1!" and nothing else.
function password(value, field = 'password') {
  if (typeof value !== 'string') throw badRequest(`${field} is required`);
  if (value.length < 8) throw badRequest('Password must be at least 8 characters');
  if (value.length > 200) throw badRequest('Password must be 200 characters or fewer');
  return value;
}

module.exports = { EMAIL_RE, str, num, int, bool, oneOf, email, dateStr, password };
