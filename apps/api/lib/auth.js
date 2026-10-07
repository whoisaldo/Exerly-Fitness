// Token issuing and request authentication.

const jwt = require('jsonwebtoken');
const { createHash } = require('node:crypto');
const { ApiError, unauthorized, forbidden } = require('./errors');

// Told only to someone holding a token this server signed for the account, so
// it reveals nothing to anyone else. A client that lost the response to its own
// deletion learns from it that the deletion happened.
const accountDeleted = () =>
  new ApiError(401, 'This account was deleted.', { code: 'account_deleted' });

/** Whether a validly signed, possibly expired, session token's account is gone. */
async function accountGone(token) {
  let claims;
  try {
    claims = jwt.verify(token, resolveSecret(), { ignoreExpiration: true });
  } catch {
    return false;
  }
  const store = require('../data');
  const user = claims.sub
    ? await store.findById('users', claims.sub)
    : await store.findOne('users', { email: claims.email });
  return !user;
}

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

// Personal access tokens reach only these paths, and never token management.
function tokenMayUse(url) {
  // Express routes paths regardless of case, so compare them that way.
  const path = url.toLowerCase();
  if (path.startsWith('/v1/tokens')) return false;
  return (
    path.startsWith('/v1/') ||
    path === '/mcp' ||
    path.startsWith('/mcp?') ||
    path.startsWith('/mcp/')
  );
}

async function authenticateToken(req, token, next) {
  try {
    const store = require('../data');
    const row = await store.findOne('personal_access_tokens', {
      token_hash: createHash('sha256').update(token).digest('hex'),
    });
    if (!row || row.revoked_at || (row.expires_at && row.expires_at <= new Date())) {
      return next(unauthorized('This token is invalid, expired or revoked.'));
    }
    const user = await store.findById('users', row.account_id);
    if (!user) return next(unauthorized('This token is invalid, expired or revoked.'));
    if (!tokenMayUse(req.originalUrl)) {
      return next(forbidden('Personal access tokens can use /v1 and /mcp only.'));
    }
    req.account = user;
    req.token = token;
    req.pat = { id: row.id, name: row.name, scopes: row.scopes, via: req.pat?.via };
    req.user = { email: user.email, name: user.name, is_admin: false, sub: String(user.id) };
    // Record use, at most once a minute.
    if (!row.last_used_at || Date.now() - row.last_used_at.getTime() > 60_000) {
      await store.update('personal_access_tokens', { id: row.id }, { last_used_at: new Date() });
    }
    return next();
  } catch (error) {
    return next(error);
  }
}

async function authenticate(req, _res, next) {
  if (req.account && req.token === readBearer(req)) return next();
  const token = readBearer(req);
  if (!token) {
    return next(unauthorized('Authorization header missing. Provide a Bearer token.'));
  }
  if (token.startsWith('exr_')) return authenticateToken(req, token, next);
  try {
    req.user = verifyToken(token);
    req.token = token;
  } catch (err) {
    const expired = err.name === 'TokenExpiredError';
    try {
      if (expired && (await accountGone(token))) return next(accountDeleted());
    } catch (error) {
      return next(error);
    }
    return next(unauthorized(expired ? 'Session expired. Log in again.' : 'Invalid token.'));
  }
  try {
    const store = require('../data');
    const user = req.user.sub
      ? await store.findById('users', req.user.sub)
      : await store.findOne('users', { email: req.user.email });
    if (!user) return next(accountDeleted());
    if ((req.user.version ?? 0) !== (user.credentials_version ?? 0))
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
