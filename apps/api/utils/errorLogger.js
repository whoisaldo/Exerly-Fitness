// AI error logging.
//
// Rewritten onto the storage adapter so local (SQLite) mode records errors too.
// It previously talked to Mongoose directly, which meant every AI failure in
// local development threw a second, unrelated error inside the error handler.

const store = require('../data');

const ERROR_TYPES = [
  'API_ERROR',
  'RATE_LIMIT',
  'VALIDATION_ERROR',
  'NETWORK_ERROR',
  'AI_MODEL_ERROR',
  'UNKNOWN_ERROR',
];
const SEVERITIES = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];
const STATUSES = ['OPEN', 'INVESTIGATING', 'RESOLVED', 'IGNORED'];

class AIErrorLogger {
  static async logError({
    email,
    userId,
    sessionId,
    errorType,
    errorCode,
    errorMessage,
    errorDetails = {},
    userAgent,
    ipAddress,
    requestData = {},
    responseData = {},
    stackTrace,
    severity = 'MEDIUM',
  }) {
    try {
      return await store.insert('ai_errors', {
        email: email || 'unknown',
        userId: String(userId || 'unknown'),
        sessionId: String(sessionId || 'unknown'),
        errorType: ERROR_TYPES.includes(errorType) ? errorType : 'UNKNOWN_ERROR',
        errorCode: String(errorCode || 'UNKNOWN'),
        errorMessage: String(errorMessage || '').slice(0, 2000),
        errorDetails,
        userAgent: userAgent ? String(userAgent).slice(0, 500) : null,
        ipAddress: ipAddress || null,
        requestData,
        responseData,
        stackTrace: stackTrace ? String(stackTrace).slice(0, 5000) : null,
        severity: SEVERITIES.includes(severity) ? severity : 'MEDIUM',
        status: 'OPEN',
        adminNotes: '',
        resolvedBy: '',
        created_at: new Date(),
        updated_at: new Date(),
      });
    } catch (err) {
      // Logging a failure must never become the failure. Swallow and move on.
      console.error('Failed to record AI error:', err.message);
      return null;
    }
  }

  static async getErrorById(id) {
    return store.findOne('ai_errors', { id: String(id) });
  }

  static async updateErrorStatus(id, status, adminNotes, resolvedBy) {
    const patch = { updated_at: new Date() };
    if (STATUSES.includes(status)) patch.status = status;
    if (adminNotes != null) patch.adminNotes = String(adminNotes).slice(0, 2000);
    if (patch.status === 'RESOLVED') {
      patch.resolvedBy = resolvedBy || '';
      patch.resolvedAt = new Date();
    }
    return store.update('ai_errors', { id: String(id) }, patch);
  }

  static async getErrorStats() {
    const [total, byStatus, bySeverity, byType] = await Promise.all([
      store.count('ai_errors', {}),
      countGrouped('status', STATUSES),
      countGrouped('severity', SEVERITIES),
      countGrouped('errorType', ERROR_TYPES),
    ]);
    return { total, byStatus, bySeverity, byType };
  }

  static async deleteOldErrors(daysOld = 30) {
    const cutoff = new Date(Date.now() - Number(daysOld) * 24 * 60 * 60 * 1000);
    return store.remove('ai_errors', { created_at: { lt: cutoff } });
  }
}

async function countGrouped(field, values) {
  const entries = await Promise.all(
    values.map(async (value) => [value, await store.count('ai_errors', { [field]: value })])
  );
  return Object.fromEntries(entries.filter(([, n]) => n > 0));
}

module.exports = AIErrorLogger;
module.exports.ERROR_TYPES = ERROR_TYPES;
module.exports.SEVERITIES = SEVERITIES;
module.exports.STATUSES = STATUSES;
