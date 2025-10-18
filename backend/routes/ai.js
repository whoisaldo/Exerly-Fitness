const express = require('express');
const router = express.Router();
const { GoogleGenerativeAI } = require("@google/generative-ai");
const AIErrorLogger = require('../utils/errorLogger');
const mongoose = require('mongoose');

// Initialize Gemini AI
const genAI = new GoogleGenerativeAI(process.env.AI_API_KEY);
const model = genAI.getGenerativeModel({ 
  model: "gemini-2.0-flash-lite",
  generationConfig: {
    maxOutputTokens: 500,
    temperature: 0.7,
  }
});

// Import models from main file to avoid circular dependencies
let User, AIPlan;

// Initialize models function
const initModels = (userModel, aiPlanModel) => {
  User = userModel;
  AIPlan = aiPlanModel;
};

// Credit management functions (imported from main file)
const checkHourlyReset = (user) => {
  const now = new Date();
  const lastReset = new Date(user.aiLastCreditReset);
  const hoursSince = (now - lastReset) / (1000 * 60 * 60);
  
  if (hoursSince >= 1) {
    user.aiCreditsRemaining = 5;
    user.aiLastCreditReset = now;
    return true;
  }
  return false;
};

const checkDailyReset = (user) => {
  const now = new Date();
  const lastReset = new Date(user.aiDailyResetDate);
  
  if (now.toDateString() !== lastReset.toDateString()) {
    user.aiDailyCreditsUsed = 0;
    user.aiDailyResetDate = now;
    return true;
  }
  return false;
};

const getTimeUntilHourlyReset = (user) => {
  const now = new Date();
  const lastReset = new Date(user.aiLastCreditReset);
  const nextReset = new Date(lastReset.getTime() + 60 * 60 * 1000);
  const diff = nextReset - now;
  
  const minutes = Math.floor(diff / 60000);
  const seconds = Math.floor((diff % 60000) / 1000);
  
  return `${minutes}:${seconds.toString().padStart(2, '0')}`;
};

const getHoursUntilMidnight = () => {
  const now = new Date();
  const midnight = new Date(now);
  midnight.setHours(24, 0, 0, 0);
  
  const diff = midnight - now;
  const hours = Math.floor(diff / (1000 * 60 * 60));
  const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
  
  return `${hours}h ${minutes}m`;
};

// Rate limiting: max 1 request per 10 seconds per user
const rateLimit = new Map();

const checkRateLimit = (userId) => {
  const now = Date.now();
  const windowMs = 10 * 1000; // 10 seconds
  const maxRequests = 1;

  if (!rateLimit.has(userId)) {
    rateLimit.set(userId, { count: 1, resetTime: now + windowMs });
    return true;
  }

  const userLimit = rateLimit.get(userId);
  
  if (now > userLimit.resetTime) {
    rateLimit.set(userId, { count: 1, resetTime: now + windowMs });
    return true;
  }

  if (userLimit.count >= maxRequests) {
    return false;
  }

  userLimit.count++;
  return true;
};

// Main AI Coach endpoint
router.post('/coach', async (req, res) => {
  const startTime = Date.now();
  let errorLogged = false;
  
  try {
    const { type, question, includeContext = true } = req.body;
    const userEmail = req.user?.email || 'unknown';
    const userId = req.user?.id || 'unknown';
    const userAgent = req.get('User-Agent') || 'unknown';
    const ipAddress = req.ip || req.connection.remoteAddress || 'unknown';

    if (!type) {
      await AIErrorLogger.logError({
        email: userEmail,
        userId,
        sessionId: 'none',
        errorType: 'VALIDATION_ERROR',
        errorCode: 'MISSING_TYPE',
        errorMessage: 'Type is required',
        errorDetails: { requestBody: req.body },
        userAgent,
        ipAddress,
        requestData: { type, question, includeContext },
        severity: 'LOW'
      });
      errorLogged = true;
      return res.status(400).json({ error: 'Type is required' });
    }

    // Check rate limit
    if (!checkRateLimit(userId)) {
      await AIErrorLogger.logError({
        email: userEmail,
        userId,
        sessionId: 'none',
        errorType: 'RATE_LIMIT',
        errorCode: 'RATE_LIMIT_EXCEEDED',
        errorMessage: 'Rate limit exceeded. Please wait 10 seconds before trying again.',
        errorDetails: { userId, rateLimitWindow: '10 seconds' },
        userAgent,
        ipAddress,
        requestData: { type, question, includeContext },
        severity: 'LOW'
      });
      errorLogged = true;
      return res.status(429).json({ 
        error: 'Rate limit exceeded. Please wait 10 seconds before trying again.' 
      });
    }

    // Get user and check credits
    const user = await User.findOne({ email: userEmail });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Check and reset credits if needed
    checkHourlyReset(user);
    checkDailyReset(user);

    // Check hourly credits
    if (user.aiCreditsRemaining <= 0) {
      const timeUntilReset = getTimeUntilHourlyReset(user);
      await user.save();
      
      return res.status(429).json({
        error: 'Hourly limit reached',
        waitTime: timeUntilReset,
        dailyUsed: user.aiDailyCreditsUsed,
        dailyLimit: 20,
        creditsRemaining: user.aiCreditsRemaining,
        dailyUsed: user.aiDailyCreditsUsed
      });
    }

    // Check daily credits
    if (user.aiDailyCreditsUsed >= 20) {
      const hoursUntilReset = getHoursUntilMidnight();
      await user.save();
      
      return res.status(429).json({
        error: 'Daily limit reached',
        resetTime: 'midnight',
        hoursUntilReset: hoursUntilReset,
        creditsRemaining: user.aiCreditsRemaining,
        dailyUsed: user.aiDailyCreditsUsed
      });
    }

    // Build context based on type and user data
    let context = '';
    let prompt = '';

    if (includeContext) {
      context = `User Profile:
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

    // Build prompts based on type
    switch (type) {
      case 'workout_plan':
        prompt = `You are an expert AI fitness coach. Create a personalized workout plan.

${context}

Instructions:
- Create a specific, actionable workout plan
- Include warm-up, main workout, and cool-down
- Specify exercises, sets, reps, and rest periods
- Consider their experience level and equipment access
- Keep it practical and achievable
- Use clear formatting with bullet points

Generate a comprehensive workout plan that they can start immediately.`;
        break;

      case 'nutrition_advice':
        prompt = `You are an expert AI nutritionist. Provide personalized nutrition advice.

${context}

Instructions:
- Give specific, actionable nutrition advice
- Consider their fitness goals and current stats
- Provide practical meal suggestions
- Include macro targets if relevant
- Keep advice simple and sustainable
- Use clear formatting with bullet points

Provide personalized nutrition guidance.`;
        break;

      case 'progress_analysis':
        prompt = `You are an expert AI fitness coach. Analyze their progress and provide insights.

${context}

Instructions:
- Analyze their current situation and goals
- Provide encouraging but honest feedback
- Suggest specific improvements
- Celebrate any progress made
- Give actionable next steps
- Keep it motivational and practical

Provide a progress analysis and recommendations.`;
        break;

      case 'custom_question':
        prompt = `You are an expert AI fitness coach. Answer their question with personalized advice.

${context}

User Question: ${question || 'No specific question provided'}

Instructions:
- Answer their question directly and helpfully
- Use their profile data to personalize the response
- Provide specific, actionable advice
- Keep responses concise but comprehensive
- Be encouraging and professional

Answer their question with personalized fitness advice.`;
        break;

      default:
        return res.status(400).json({ error: 'Invalid type. Must be workout_plan, nutrition_advice, progress_analysis, or custom_question' });
    }

    // Call AI
    const result = await model.generateContent(prompt);
    const response = result.response.text();

    // Save to database
    const aiPlan = new AIPlan({
      userId: user._id,
      type,
      prompt,
      response,
      creditsUsedAtTime: {
        hourly: user.aiCreditsRemaining,
        daily: user.aiDailyCreditsUsed
      }
    });
    await aiPlan.save();

    // Update user credits
    user.aiCreditsRemaining -= 1;
    user.aiDailyCreditsUsed += 1;
    await user.save();

    const responseTime = Date.now() - startTime;
    console.log(`✅ AI Coach Success: ${userEmail} - Type: ${type} - ${responseTime}ms`);

    res.json({
      response,
      type,
      creditsRemaining: user.aiCreditsRemaining,
      dailyUsed: user.aiDailyCreditsUsed,
      nextResetTime: getTimeUntilHourlyReset(user)
    });

  } catch (error) {
    console.error('AI Coach Error:', error);
    
    if (!errorLogged) {
      const errorType = error.name === 'GoogleGenerativeAIFetchError' ? 'AI_MODEL_ERROR' : 
                       error.code === 'ENOTFOUND' ? 'NETWORK_ERROR' : 'UNKNOWN_ERROR';
      
      const errorCode = error.status ? `HTTP_${error.status}` : 
                       error.code || 'UNKNOWN_ERROR';
      
      const severity = errorType === 'AI_MODEL_ERROR' ? 'HIGH' : 
                      errorType === 'NETWORK_ERROR' ? 'MEDIUM' : 'LOW';

      await AIErrorLogger.logError({
        email: req.user?.email || 'unknown',
        userId: req.user?.id || 'unknown',
        sessionId: 'none',
        errorType,
        errorCode,
        errorMessage: error.message || 'Unknown error occurred',
        errorDetails: {
          errorName: error.name,
          errorStatus: error.status,
          errorCode: error.code,
          stack: error.stack
        },
        userAgent: req.get('User-Agent') || 'unknown',
        ipAddress: req.ip || req.connection.remoteAddress || 'unknown',
        requestData: {
          type: req.body.type,
          question: req.body.question,
          includeContext: req.body.includeContext
        },
        responseData: { status: 500 },
        stackTrace: error.stack,
        severity
      });
    }

    res.status(500).json({ 
      error: 'Sorry, I encountered an error. Please try again later.',
      errorId: error.id || 'unknown'
    });
  }
});

// Get saved AI plans
router.get('/plans', async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const plans = await AIPlan.find({ userId }).sort({ createdAt: -1 }).limit(20);
    res.json(plans);
  } catch (error) {
    console.error('Error fetching AI plans:', error);
    res.status(500).json({ error: 'Error fetching plans' });
  }
});

// Delete AI plan
router.delete('/plans/:id', async (req, res) => {
  try {
    const userId = req.user?.id;
    const planId = req.params.id;
    
    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const result = await AIPlan.deleteOne({ _id: planId, userId });
    if (result.deletedCount === 0) {
      return res.status(404).json({ error: 'Plan not found' });
    }

    res.json({ message: 'Plan deleted successfully' });
  } catch (error) {
    console.error('Error deleting AI plan:', error);
    res.status(500).json({ error: 'Error deleting plan' });
  }
});

// Mark plan as applied
router.patch('/plans/:id/apply', async (req, res) => {
  try {
    const userId = req.user?.id;
    const planId = req.params.id;
    
    if (!userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const result = await AIPlan.updateOne(
      { _id: planId, userId }, 
      { applied: true }
    );
    
    if (result.matchedCount === 0) {
      return res.status(404).json({ error: 'Plan not found' });
    }

    res.json({ message: 'Plan marked as applied' });
  } catch (error) {
    console.error('Error applying AI plan:', error);
    res.status(500).json({ error: 'Error applying plan' });
  }
});

// Clean up old conversations every hour
setInterval(() => {
  const now = Date.now();
  const maxAge = 60 * 60 * 1000; // 1 hour
  
  for (const [userId, userLimit] of rateLimit.entries()) {
    if (now > userLimit.resetTime) {
      rateLimit.delete(userId);
    }
  }
}, 60 * 60 * 1000);

module.exports = { router, initModels };