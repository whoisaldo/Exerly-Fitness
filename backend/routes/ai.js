const express = require('express');
const router = express.Router();
const { GoogleGenerativeAI } = require("@google/generative-ai");
const AIErrorLogger = require('../utils/errorLogger');

// Initialize Gemini AI
const genAI = new GoogleGenerativeAI(process.env.AI_API_KEY);
const model = genAI.getGenerativeModel({ 
  model: "gemini-2.0-flash-lite",
  generationConfig: {
    maxOutputTokens: 200,
    temperature: 0.7,
  }
});

// Store conversations in memory (temporary - can move to DB later)
const conversations = new Map();

// Rate limiting: max 10 requests per minute per session
const rateLimit = new Map();

const CONSULTATION_TOPICS = [
  "fitness goals",
  "current fitness level", 
  "workout schedule",
  "equipment access",
  "health considerations"
];

// Rate limiting middleware
const checkRateLimit = (sessionId) => {
  const now = Date.now();
  const windowMs = 60 * 1000; // 1 minute
  const maxRequests = 10;

  if (!rateLimit.has(sessionId)) {
    rateLimit.set(sessionId, { count: 1, resetTime: now + windowMs });
    return true;
  }

  const userLimit = rateLimit.get(sessionId);
  
  if (now > userLimit.resetTime) {
    // Reset the window
    rateLimit.set(sessionId, { count: 1, resetTime: now + windowMs });
    return true;
  }

  if (userLimit.count >= maxRequests) {
    return false;
  }

  userLimit.count++;
  return true;
};

router.post('/fitness-chat', async (req, res) => {
  const startTime = Date.now();
  let errorLogged = false;
  
  try {
    const { message, sessionId, useProfileData, userProfile, userStats } = req.body;
    const userEmail = req.user?.email || 'unknown';
    const userId = req.user?.id || 'unknown';
    const userAgent = req.get('User-Agent') || 'unknown';
    const ipAddress = req.ip || req.connection.remoteAddress || 'unknown';

    if (!sessionId) {
      await AIErrorLogger.logError({
        email: userEmail,
        userId,
        sessionId: 'none',
        errorType: 'VALIDATION_ERROR',
        errorCode: 'MISSING_SESSION_ID',
        errorMessage: 'Session ID is required',
        errorDetails: { requestBody: req.body },
        userAgent,
        ipAddress,
        requestData: { message, useProfileData, hasUserProfile: !!userProfile, hasUserStats: !!userStats },
        severity: 'LOW'
      });
      errorLogged = true;
      return res.status(400).json({ error: 'Session ID is required' });
    }

    // Check rate limit
    if (!checkRateLimit(sessionId)) {
      await AIErrorLogger.logError({
        email: userEmail,
        userId,
        sessionId,
        errorType: 'RATE_LIMIT',
        errorCode: 'RATE_LIMIT_EXCEEDED',
        errorMessage: 'Rate limit exceeded. Please wait a minute before trying again.',
        errorDetails: { sessionId, rateLimitWindow: '1 minute' },
        userAgent,
        ipAddress,
        requestData: { message, useProfileData, hasUserProfile: !!userProfile, hasUserStats: !!userStats },
        severity: 'LOW'
      });
      errorLogged = true;
      return res.status(429).json({ 
        error: 'Rate limit exceeded. Please wait a minute before trying again.' 
      });
    }

    // Get or create conversation
    let conversation = conversations.get(sessionId) || {
      topics: new Set(),
      answers: {},
      history: [],
      isComplete: false,
      createdAt: Date.now()
    };

    // Store user's message in history
    if (message) {
      conversation.history.push({ role: 'user', content: message });
    }

    // Build context for AI
    let profileContext = '';
    if (useProfileData && userProfile) {
      profileContext = `User Profile:
- Name: ${userProfile.name || 'Not specified'}
- Age: ${userProfile.age || 'Not specified'}
- Weight: ${userProfile.weight_kg || 'Not specified'} kg
- Height: ${userProfile.height_cm || 'Not specified'} cm
- Gender: ${userProfile.sex || 'Not specified'}
- Activity Level: ${userProfile.activity_level || 'Not specified'}`;
    }

    let statsContext = '';
    if (useProfileData && userStats && userStats.length > 0) {
      statsContext = `Recent Activity:
${userStats.map(stat => `- ${stat.label}: ${stat.value}`).join('\n')}`;
    }

    // Create intelligent conversation prompt
    const conversationHistory = conversation.history.map(msg => 
      `${msg.role === 'user' ? 'User' : 'AI'}: ${msg.content}`
    ).join('\n');

    const prompt = `You are an intelligent, personalized AI fitness coach. You're having a natural conversation with a user to understand their fitness needs and create a customized plan.

${profileContext ? profileContext + '\n' : ''}${statsContext ? statsContext + '\n' : ''}

Conversation so far:
${conversationHistory}

Topics we've discussed: ${Array.from(conversation.topics).join(', ') || 'None yet'}

Instructions:
1. If this is the first message (no conversation history), greet them warmly and ask about their fitness goals
2. Have a natural conversation to understand their:
   - Fitness goals and motivations
   - Current fitness level and experience
   - Available time and schedule
   - Equipment access
   - Any health considerations or limitations
3. Ask follow-up questions based on their responses
4. Be encouraging, knowledgeable, and personalized
5. When you have enough information (usually after 4-6 exchanges), create a comprehensive fitness plan
6. Make responses feel natural and conversational, not robotic
7. Use their name and reference their profile data when relevant

Current user message: ${message || '(Starting conversation)'}

Respond naturally and helpfully. If you're ready to create a plan, end your response with "PLAN_READY:" followed by the plan.`;

    const result = await model.generateContent(prompt);
    const response = result.response.text();

    // Check if AI is ready to provide a plan
    if (response.includes('PLAN_READY:')) {
      const plan = response.split('PLAN_READY:')[1].trim();
      
      // Clean up conversation after sending plan
      conversations.delete(sessionId);

      const responseTime = Date.now() - startTime;
      console.log(`✅ AI Chat Success: ${userEmail} - ${responseTime}ms`);

      return res.json({
        reply: plan,
        questionNumber: 5,
        isComplete: true,
        plan: plan,
        answers: conversation.answers
      });
    }

    // Store AI response in history
    conversation.history.push({ role: 'assistant', content: response });
    
    // Update topics based on conversation content
    const responseLower = response.toLowerCase();
    if (responseLower.includes('goal') || responseLower.includes('want to')) {
      conversation.topics.add('fitness goals');
    }
    if (responseLower.includes('level') || responseLower.includes('experience') || responseLower.includes('beginner') || responseLower.includes('advanced')) {
      conversation.topics.add('current fitness level');
    }
    if (responseLower.includes('day') || responseLower.includes('schedule') || responseLower.includes('time')) {
      conversation.topics.add('workout schedule');
    }
    if (responseLower.includes('equipment') || responseLower.includes('gym') || responseLower.includes('home')) {
      conversation.topics.add('equipment access');
    }
    if (responseLower.includes('injury') || responseLower.includes('limitation') || responseLower.includes('health')) {
      conversation.topics.add('health considerations');
    }

    conversations.set(sessionId, conversation);

    const responseTime = Date.now() - startTime;
    console.log(`✅ AI Chat Response: ${userEmail} - Topics: ${Array.from(conversation.topics).join(', ')} - ${responseTime}ms`);

    res.json({
      reply: response,
      questionNumber: conversation.topics.size + 1,
      isComplete: false
    });

  } catch (error) {
    console.error('AI Chat Error:', error);
    
    // Log error if not already logged
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
        sessionId: req.body.sessionId || 'unknown',
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
          message: req.body.message,
          useProfileData: req.body.useProfileData,
          hasUserProfile: !!req.body.userProfile,
          hasUserStats: !!req.body.userStats
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

// Clean up old conversations every hour
setInterval(() => {
  const now = Date.now();
  const maxAge = 60 * 60 * 1000; // 1 hour
  
  for (const [sessionId, conversation] of conversations.entries()) {
    if (now - conversation.createdAt > maxAge) {
      conversations.delete(sessionId);
    }
  }
}, 60 * 60 * 1000);

module.exports = router;
