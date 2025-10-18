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

const QUESTIONS = [
  "What is your primary fitness goal? (e.g., lose weight, build muscle, improve endurance, stay healthy)",
  "What is your current fitness level? (beginner, intermediate, or advanced)",
  "How many days per week can you realistically commit to working out? (1-7 days)",
  "Do you have access to gym equipment, or will you be working out at home?",
  "Do you have any injuries or physical limitations I should know about?"
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
      questionIndex: 0,
      answers: [],
      history: []
    };

    // Store user's answer if provided
    if (message && conversation.questionIndex < QUESTIONS.length) {
      conversation.answers.push(message);
      conversation.history.push({ role: 'user', content: message });
    }

    // Check if we're done with questions
    if (conversation.questionIndex >= QUESTIONS.length) {
      // Generate personalized plan with user profile data
      let profileContext = '';
      if (useProfileData && userProfile) {
        profileContext = `\n\nUser Profile Data:
- Age: ${userProfile.age || 'Not specified'}
- Weight: ${userProfile.weight_kg || 'Not specified'} kg
- Height: ${userProfile.height_cm || 'Not specified'} cm
- Gender: ${userProfile.sex || 'Not specified'}
- Activity Level: ${userProfile.activity_level || 'Not specified'}`;
      }

      let statsContext = '';
      if (useProfileData && userStats && userStats.length > 0) {
        statsContext = `\n\nRecent Activity Summary:
${userStats.map(stat => `- ${stat.label}: ${stat.value}`).join('\n')}`;
      }

      const prompt = `You are a certified personal trainer and nutritionist. Based on these user answers, create a personalized fitness plan:

1. Primary Goal: ${conversation.answers[0] || 'Not specified'}
2. Fitness Level: ${conversation.answers[1] || 'Not specified'}
3. Workout Days: ${conversation.answers[2] || 'Not specified'}
4. Equipment Access: ${conversation.answers[3] || 'Not specified'}
5. Limitations: ${conversation.answers[4] || 'None mentioned'}${profileContext}${statsContext}

Provide a brief but actionable plan including:
- A workout split for their available days
- 3-5 key exercises with brief descriptions
- One specific nutrition tip for their goal
- A motivational closing statement

Keep it under 150 words and make it practical and encouraging. Reference their profile data when relevant to make it feel personalized.`;

      const result = await model.generateContent(prompt);
      const plan = result.response.text();

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

    // Smart question skipping based on profile data
    let nextQuestion = QUESTIONS[conversation.questionIndex];
    let questionNumber = conversation.questionIndex + 1;

    // Skip questions if we have profile data and user wants to use it
    if (useProfileData && userProfile) {
      // Skip goal question if user already has a goal in profile
      if (conversation.questionIndex === 0 && userProfile.goal) {
        conversation.answers.push(userProfile.goal);
        conversation.questionIndex++;
        nextQuestion = QUESTIONS[conversation.questionIndex];
        questionNumber = conversation.questionIndex + 1;
      }

      // Skip fitness level question if we can infer from workout history
      if (conversation.questionIndex === 1 && userStats && userStats.length > 0) {
        const hasWorkouts = userStats.some(stat => stat.label.toLowerCase().includes('workout'));
        if (hasWorkouts) {
          conversation.answers.push('intermediate'); // Default to intermediate if they have workout history
          conversation.questionIndex++;
          nextQuestion = QUESTIONS[conversation.questionIndex];
          questionNumber = conversation.questionIndex + 1;
        }
      }
    }

    // Add personalization to questions
    if (useProfileData && userProfile) {
      const name = userProfile.name || 'there';
      if (conversation.questionIndex === 0) {
        nextQuestion = `Hi ${name}! What is your primary fitness goal? (e.g., lose weight, build muscle, improve endurance, stay healthy)`;
      } else if (conversation.questionIndex === 1) {
        nextQuestion = `What is your current fitness level, ${name}? (beginner, intermediate, or advanced)`;
      } else if (conversation.questionIndex === 2) {
        nextQuestion = `How many days per week can you realistically commit to working out, ${name}? (1-7 days)`;
      } else if (conversation.questionIndex === 3) {
        nextQuestion = `Do you have access to gym equipment, or will you be working out at home, ${name}?`;
      } else if (conversation.questionIndex === 4) {
        nextQuestion = `Do you have any injuries or physical limitations I should know about, ${name}?`;
      }
    }

    conversation.questionIndex++;
    conversations.set(sessionId, conversation);

    const responseTime = Date.now() - startTime;
    console.log(`✅ AI Chat Question: ${userEmail} - Q${questionNumber} - ${responseTime}ms`);

    res.json({
      reply: nextQuestion,
      questionNumber: questionNumber,
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
