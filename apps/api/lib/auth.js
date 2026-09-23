// Token issuing and request authentication.

const jwt = require('jsonwebtoken');
const { unauthorized, forbidden } = require('./errors');

// In production a missing secret is fatal: signing with a value that's in the
// public repo would let anyone mint an admin token.
function resolveSecret() {
  if (process.env.NODE_ENV === 'production' && !process.env.JWT_SECRET) {
    throw new Error('JWT_SECRET is required in production');
  }
  return process.env.JWT_SECRET || 'development-jwt-secret-change-in-production';
}

// 12 hours meant logging in again every single day, which is the fastest way to
// stop using a habit-tracking app. 30 days with a refresh endpoint is the
// trade-off a personal fitness tracker should make.
const DEFAULT_EXPIRY = process.env.JWT_EXPIRES_IN || '30d';

function signToken(user, expiresIn = DEFAULT_EXPIRY, claims = {}) {
  return jwt.sign(
    {
      email: user.email,
      name: user.name,
      is_admin: !!user.is_admin,
      sub: String(user.id),
      ...claims,
    },
    resolveSecret(),
    { expiresIn }
  );
}

function verifyToken(token) {
  return jwt.verify(token, resolveSecret());
}

function readBearer(req) {
  const header = req.headers.authorization;
  if (!header) return null;
  const parts = header.split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer') return null;
  return parts[1];
}

async function authenticate(req, _res, next) {
  if (req.account && req.token === readBearer(req)) return next();
  const token = readBearer(req);
  if (!token) {
    return next(unauthorized('Authorization header missing. Provide a Bearer token.'));
  }
  try {
    req.user = verifyToken(token);
    req.token = token;
  } catch (err) {
    const expired = err.name === 'TokenExpiredError';
    return next(unauthorized(expired ? 'Session expired. Log in again.' : 'Invalid token.'));
  }
  try {
    const store = require('../data');
    const user = req.user.sub
      ? await store.findById('users', req.user.sub)
      : await store.findOne('users', { email: req.user.email });
    if (!user || (req.user.version ?? 0) !== (user.credentials_version ?? 0))
      return next(unauthorized('Session has been revoked'));
    if (req.user.sid) {
      const session = await store.findOne('sessions', {
        session_id: req.user.sid,
        account_id: user.id,
      });
      if (!require('./sessions').isActive(session, user))
        return next(unauthorized('Session has been revoked'));
    } else if (
      !Number.isFinite(req.user.iat) ||
      Date.now() / 1000 > req.user.iat + 30 * 86400 ||
      (process.env.LEGACY_JWT_ACCEPT_UNTIL &&
        new Date() > new Date(process.env.LEGACY_JWT_ACCEPT_UNTIL))
    ) {
      return next(unauthorized('Sign in again to update your session'));
    }
    req.account = user;
    req.user = { ...req.user, email: user.email, name: user.name, is_admin: !!user.is_admin };
    return next();
  } catch (error) {
    return next(error);
  }
}

function requireAdmin(req, _res, next) {
  if (!req.account?.is_admin) return next(forbidden('Admin only'));
  next();
}

function adminEmails() {
  return (process.env.ADMIN_EMAILS || process.env.ADMIN_EMAIL || '')
    .toLowerCase()
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

module.exports = {
  signToken,
  verifyToken,
  readBearer,
  authenticate,
  requireAdmin,
  adminEmails,
  DEFAULT_EXPIRY,
  resolveSecret,
};
