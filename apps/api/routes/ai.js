const express = require('express');
const jwt = require('jsonwebtoken');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const AIErrorLogger = require('../utils/errorLogger');

const router = express.Router();

const SECRET = process.env.JWT_SECRET || 'development-jwt-secret-change-in-production';
const genAI = (process.env.GEMINI_API_KEY || process.env.AI_API_KEY)
  ? new GoogleGenerativeAI(process.env.GEMINI_API_KEY || process.env.AI_API_KEY)
  : null;
const model = genAI ? genAI.getGenerativeModel({
  model: 'gemini-2.0-flash-lite',
  generationConfig: {
    maxOutputTokens: 500,
    temperature: 0.7,
  },
}) : null;

let User;
let AIPlan;

const rateLimit = new Map();

function initModels(userModel, aiPlanModel) {
  User = userModel;
  AIPlan = aiPlanModel;
}

router.use((req, res, next) => {
  if (req.user) return next();

  const auth = req.headers.authorization;
  if (!auth) {
    return res.status(401).json({ error: 'Authorization header missing' });
  }

  const parts = auth.split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer') {
    return res.status(401).json({ error: 'Invalid authorization format. Use: Bearer <token>' });
  }

  try {
    req.user = jwt.verify(parts[1], SECRET);
    return next();
  } catch {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
});

function checkHourlyReset(user) {
  const now = new Date();
  const lastReset = new Date(user.aiLastCreditReset);
  const hoursSince = (now - lastReset) / (1000 * 60 * 60);

  if (hoursSince >= 1) {
    user.aiCreditsRemaining = 5;
    user.aiLastCreditReset = now;
    return true;
  }

  return false;
}

function checkDailyReset(user) {
  const now = new Date();
  const lastReset = new Date(user.aiDailyResetDate);

  if (now.toDateString() !== lastReset.toDateString()) {
    user.aiDailyCreditsUsed = 0;
    user.aiDailyResetDate = now;
    return true;
  }

  return false;
}

function getTimeUntilHourlyReset(user) {
  const now = new Date();
  const lastReset = new Date(user.aiLastCreditReset);
  const nextReset = new Date(lastReset.getTime() + 60 * 60 * 1000);
  const diff = Math.max(0, nextReset - now);
  const minutes = Math.floor(diff / 60000);
  const seconds = Math.floor((diff % 60000) / 1000);

  return `${minutes}:${seconds.toString().padStart(2, '0')}`;
}

function getHoursUntilMidnight() {
  const now = new Date();
  const midnight = new Date(now);
  midnight.setHours(24, 0, 0, 0);

  const diff = midnight - now;
  const hours = Math.floor(diff / (1000 * 60 * 60));
  const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));

  return `${hours}h ${minutes}m`;
}

function checkRateLimit(userId) {
  const now = Date.now();
  const windowMs = 10 * 1000;

  if (!rateLimit.has(userId)) {
    rateLimit.set(userId, { count: 1, resetTime: now + windowMs });
    return true;
  }

  const userLimit = rateLimit.get(userId);
  if (now > userLimit.resetTime) {
    rateLimit.set(userId, { count: 1, resetTime: now + windowMs });
    return true;
  }

  if (userLimit.count >= 1) {
    return false;
  }

  userLimit.count += 1;
  return true;
}

function serializePlan(plan) {
  const source = typeof plan.toObject === 'function' ? plan.toObject() : plan;
  return {
    _id: source._id ? String(source._id) : undefined,
    type: source.type || 'custom_question',
    prompt: source.prompt || '',
    response: source.response || '',
    createdAt: source.createdAt || source.created_at || null,
    applied: !!source.applied,
  };
}

function buildContext(user, includeContext) {
  if (!includeContext) return '';

  return `User Profile:
- Name: ${user.name || 'Not specified'}
- Age: ${user.age || 'Not specified'}
- Gender: ${user.gender || 'Not specified'}
- Height: ${user.height || 'Not specified'} cm
- Weight: ${user.weight || 'Not specified'} kg
- Goal: ${user.goal || 'Not specified'}
- Experience Level: ${user.experienceLevel || 'Not specified'}
- Workout Days/Week: ${user.workoutDaysPerWeek || 'Not specified'}
- Equipment Access: ${user.equipmentAccess || 'Not specified'}`;
}

function buildPrompt(type, question, context) {
  switch (type) {
    case 'workout_plan':
      return `You are an expert AI fitness coach. Create a personalized workout plan.

${context}

Instructions:
- Create a specific, actionable workout plan
- Include warm-up, main workout, and cool-down
- Specify exercises, sets, reps, and rest periods
- Consider their experience level and equipment access
- Keep it practical and achievable
- Use clear formatting with bullet points

Generate a comprehensive workout plan that they can start immediately.`;
    case 'nutrition_advice':
      return `You are an expert AI nutritionist. Provide personalized nutrition advice.

${context}

Instructions:
- Give specific, actionable nutrition advice
- Consider their fitness goals and current stats
- Provide practical meal suggestions
- Include macro targets if relevant
- Keep advice simple and sustainable
- Use clear formatting with bullet points

Provide personalized nutrition guidance.`;
    case 'progress_analysis':
      return `You are an expert AI fitness coach. Analyze their progress and provide insights.

${context}

Instructions:
- Analyze their current situation and goals
- Provide encouraging but honest feedback
- Suggest specific improvements
- Celebrate any progress made
- Give actionable next steps
- Keep it motivational and practical

Provide a progress analysis and recommendations.`;
    case 'custom_question':
      return `You are an expert AI fitness coach. Answer their question with personalized advice.

${context}

User Question: ${question || 'No specific question provided'}

Instructions:
- Answer their question directly and helpfully
- Use their profile data to personalize the response
- Provide specific, actionable advice
- Keep responses concise but comprehensive
- Be encouraging and professional

Answer their question with personalized fitness advice.`;
    default:
      return null;
  }
}

router.post('/coach', async (req, res) => {
  const startedAt = Date.now();
  let errorLogged = false;

  try {
    if (!User || !AIPlan) {
      return res.status(500).json({ error: 'AI routes are not initialized' });
    }

    if (!model) {
      return res.status(503).json({ error: 'AI service is not configured' });
    }

    const { type, question, includeContext = true } = req.body || {};
    const userEmail = req.user?.email || 'unknown';
    const userAgent = req.get('User-Agent') || 'unknown';
    const ipAddress = req.ip || req.connection.remoteAddress || 'unknown';

    if (!type) {
      await AIErrorLogger.logError({
        email: userEmail,
        userId: userEmail,
        sessionId: 'none',
        errorType: 'VALIDATION_ERROR',
        errorCode: 'MISSING_TYPE',
        errorMessage: 'Type is required',
        errorDetails: { requestBody: req.body },
        userAgent,
        ipAddress,
        requestData: { type, question, includeContext },
        severity: 'LOW',
      });
      errorLogged = true;
      return res.status(400).json({ error: 'Type is required' });
    }

    const prompt = buildPrompt(type, question, '');
    if (!prompt && type !== 'custom_question') {
      return res.status(400).json({
        error: 'Invalid type. Must be workout_plan, nutrition_advice, progress_analysis, or custom_question',
      });
    }

    const user = await User.findOne({ email: userEmail });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    if (!checkRateLimit(user.email)) {
      await AIErrorLogger.logError({
        email: user.email,
        userId: user.email,
        sessionId: 'none',
        errorType: 'RATE_LIMIT',
        errorCode: 'RATE_LIMIT_EXCEEDED',
        errorMessage: 'Rate limit exceeded. Please wait 10 seconds before trying again.',
        errorDetails: { rateLimitWindow: '10 seconds' },
        userAgent,
        ipAddress,
        requestData: { type, question, includeContext },
        severity: 'LOW',
      });
      errorLogged = true;
      return res.status(429).json({ error: 'Rate limit exceeded. Please wait 10 seconds before trying again.' });
    }

    checkHourlyReset(user);
    checkDailyReset(user);

    if (user.aiCreditsRemaining <= 0) {
      await user.save();
      return res.status(429).json({
        error: 'Hourly limit reached',
        waitTime: getTimeUntilHourlyReset(user),
        creditsRemaining: user.aiCreditsRemaining,
        dailyUsed: user.aiDailyCreditsUsed,
        dailyLimit: 20,
      });
    }

    if (user.aiDailyCreditsUsed >= 20) {
      await user.save();
      return res.status(429).json({
        error: 'Daily limit reached',
        resetTime: 'midnight',
        hoursUntilReset: getHoursUntilMidnight(),
        creditsRemaining: user.aiCreditsRemaining,
        dailyUsed: user.aiDailyCreditsUsed,
      });
    }

    const finalPrompt = buildPrompt(type, question, buildContext(user, includeContext));
    const result = await model.generateContent(finalPrompt);
    const response = result.response.text();

    const aiPlan = await AIPlan.create({
      userId: user._id,
      type,
      prompt: finalPrompt,
      response,
      applied: false,
      creditsUsedAtTime: {
        hourly: user.aiCreditsRemaining,
        daily: user.aiDailyCreditsUsed,
      },
    });

    user.aiCreditsRemaining -= 1;
    user.aiDailyCreditsUsed += 1;
    await user.save();

    console.log(`✅ AI Coach Success: ${userEmail} - Type: ${type} - ${Date.now() - startedAt}ms`);

    return res.json({
      response,
      creditsRemaining: user.aiCreditsRemaining,
      dailyUsed: user.aiDailyCreditsUsed,
      planId: String(aiPlan._id),
    });
  } catch (error) {
    console.error('AI Coach Error:', error);

    if (!errorLogged) {
      const errorType = error.name === 'GoogleGenerativeAIFetchError'
        ? 'AI_MODEL_ERROR'
        : (error.code === 'ENOTFOUND' ? 'NETWORK_ERROR' : 'UNKNOWN_ERROR');
      const errorCode = error.status ? `HTTP_${error.status}` : (error.code || 'UNKNOWN_ERROR');
      const severity = errorType === 'AI_MODEL_ERROR'
        ? 'HIGH'
        : (errorType === 'NETWORK_ERROR' ? 'MEDIUM' : 'LOW');

      await AIErrorLogger.logError({
        email: req.user?.email || 'unknown',
        userId: req.user?.email || 'unknown',
        sessionId: 'none',
        errorType,
        errorCode,
        errorMessage: error.message || 'Unknown error occurred',
        errorDetails: {
          errorName: error.name,
          errorStatus: error.status,
          errorCode: error.code,
          stack: error.stack,
        },
        userAgent: req.get('User-Agent') || 'unknown',
        ipAddress: req.ip || req.connection.remoteAddress || 'unknown',
        requestData: {
          type: req.body?.type,
          question: req.body?.question,
          includeContext: req.body?.includeContext,
        },
        responseData: { status: 500 },
        stackTrace: error.stack,
        severity,
      });
    }

    return res.status(500).json({
      error: 'Sorry, I encountered an error. Please try again later.',
    });
  }
});

router.get('/plans', async (req, res) => {
  try {
    if (!User || !AIPlan) {
      return res.status(500).json({ error: 'AI routes are not initialized' });
    }

    const user = await User.findOne({ email: req.user?.email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const plans = await AIPlan.find({ userId: user._id }).sort({ createdAt: -1 }).limit(20);
    return res.json(plans.map(serializePlan));
  } catch (error) {
    console.error('Error fetching AI plans:', error);
    return res.status(500).json({ error: 'Error fetching plans' });
  }
});

router.delete('/plans/:id', async (req, res) => {
  try {
    if (!User || !AIPlan) {
      return res.status(500).json({ error: 'AI routes are not initialized' });
    }

    const user = await User.findOne({ email: req.user?.email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const deleted = await AIPlan.findOneAndDelete({ _id: req.params.id, userId: user._id });
    if (!deleted) {
      return res.status(404).json({ error: 'Plan not found' });
    }

    return res.json({ message: 'Plan deleted successfully' });
  } catch (error) {
    console.error('Error deleting AI plan:', error);
    return res.status(500).json({ error: 'Error deleting plan' });
  }
});

router.patch('/plans/:id/apply', async (req, res) => {
  try {
    if (!User || !AIPlan) {
      return res.status(500).json({ error: 'AI routes are not initialized' });
    }

    const user = await User.findOne({ email: req.user?.email });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const updated = await AIPlan.findOneAndUpdate(
      { _id: req.params.id, userId: user._id },
      { applied: true },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ error: 'Plan not found' });
    }

    return res.json({
      message: 'Plan marked as applied',
      plan: serializePlan(updated),
    });
  } catch (error) {
    console.error('Error applying AI plan:', error);
    return res.status(500).json({ error: 'Error applying plan' });
  }
});

setInterval(() => {
  const now = Date.now();
  for (const [userId, userLimit] of rateLimit.entries()) {
    if (now > userLimit.resetTime) {
      rateLimit.delete(userId);
    }
  }
}, 60 * 60 * 1000);

module.exports = { router, initModels };
