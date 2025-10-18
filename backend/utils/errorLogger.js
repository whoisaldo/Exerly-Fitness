const mongoose = require('mongoose');

const aiErrorSchema = new mongoose.Schema({
  email: { type: String, required: true, index: true },
  userId: { type: String, required: true, index: true },
  sessionId: { type: String, required: true, index: true },
  errorType: { 
    type: String, 
    required: true,
    enum: ['API_ERROR', 'RATE_LIMIT', 'VALIDATION_ERROR', 'NETWORK_ERROR', 'AI_MODEL_ERROR', 'UNKNOWN_ERROR']
  },
  errorCode: { type: String, required: true },
  errorMessage: { type: String, required: true },
  errorDetails: { type: mongoose.Schema.Types.Mixed, default: {} },
  userAgent: { type: String },
  ipAddress: { type: String },
  requestData: { type: mongoose.Schema.Types.Mixed, default: {} },
  responseData: { type: mongoose.Schema.Types.Mixed, default: {} },
  stackTrace: { type: String },
  severity: { 
    type: String, 
    enum: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'],
    default: 'MEDIUM'
  },
  status: { 
    type: String, 
    enum: ['OPEN', 'INVESTIGATING', 'RESOLVED', 'IGNORED'],
    default: 'OPEN'
  },
  adminNotes: { type: String, default: '' },
  resolvedBy: { type: String, default: '' },
  resolvedAt: { type: Date },
  created_at: { type: Date, default: Date.now },
  updated_at: { type: Date, default: Date.now }
});

const AIError = mongoose.model('AIError', aiErrorSchema);

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
    severity = 'MEDIUM'
  }) {
    try {
      const error = new AIError({
        email,
        userId,
        sessionId,
        errorType,
        errorCode,
        errorMessage,
        errorDetails,
        userAgent,
        ipAddress,
        requestData,
        responseData,
        stackTrace,
        severity,
        status: 'OPEN'
      });

      await error.save();
      
      // Log to console for immediate debugging
      console.error(`🚨 AI Error Logged:`, {
        email,
        errorType,
        errorCode,
        errorMessage,
        severity,
        timestamp: new Date().toISOString()
      });

      return error;
    } catch (logError) {
      console.error('Failed to log AI error:', logError);
      return null;
    }
  }

  static async getErrorStats() {
    try {
      const stats = await AIError.aggregate([
        {
          $group: {
            _id: {
              errorType: '$errorType',
              severity: '$severity',
              status: '$status'
            },
            count: { $sum: 1 },
            latestError: { $max: '$created_at' }
          }
        },
        {
          $group: {
            _id: '$_id.errorType',
            totalCount: { $sum: '$count' },
            bySeverity: {
              $push: {
                severity: '$_id.severity',
                status: '$_id.status',
                count: '$count',
                latestError: '$latestError'
              }
            }
          }
        }
      ]);

      const totalErrors = await AIError.countDocuments();
      const openErrors = await AIError.countDocuments({ status: 'OPEN' });
      const criticalErrors = await AIError.countDocuments({ severity: 'CRITICAL' });

      return {
        totalErrors,
        openErrors,
        criticalErrors,
        byType: stats
      };
    } catch (error) {
      console.error('Failed to get error stats:', error);
      return null;
    }
  }

  static async getRecentErrors(limit = 50) {
    try {
      return await AIError.find()
        .sort({ created_at: -1 })
        .limit(limit)
        .populate('email', 'name email')
        .lean();
    } catch (error) {
      console.error('Failed to get recent errors:', error);
      return [];
    }
  }

  static async updateErrorStatus(errorId, status, adminNotes = '', resolvedBy = '') {
    try {
      const updateData = {
        status,
        updated_at: new Date()
      };

      if (status === 'RESOLVED') {
        updateData.resolvedBy = resolvedBy;
        updateData.resolvedAt = new Date();
      }

      if (adminNotes) {
        updateData.adminNotes = adminNotes;
      }

      return await AIError.findByIdAndUpdate(errorId, updateData, { new: true });
    } catch (error) {
      console.error('Failed to update error status:', error);
      return null;
    }
  }

  static async getErrorsByUser(email, limit = 20) {
    try {
      return await AIError.find({ email })
        .sort({ created_at: -1 })
        .limit(limit)
        .lean();
    } catch (error) {
      console.error('Failed to get errors by user:', error);
      return [];
    }
  }

  static async getErrorById(errorId) {
    try {
      return await AIError.findById(errorId).lean();
    } catch (error) {
      console.error('Failed to get error by ID:', error);
      return null;
    }
  }

  static async deleteOldErrors(daysOld = 30) {
    try {
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - daysOld);

      const result = await AIError.deleteMany({
        created_at: { $lt: cutoffDate },
        status: { $in: ['RESOLVED', 'IGNORED'] }
      });

      console.log(`Deleted ${result.deletedCount} old AI errors`);
      return result.deletedCount;
    } catch (error) {
      console.error('Failed to delete old errors:', error);
      return 0;
    }
  }
}

module.exports = AIErrorLogger;
