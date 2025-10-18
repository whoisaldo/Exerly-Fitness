import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import './AICoach.css';

const AICoach = () => {
  const [userProfile, setUserProfile] = useState(null);
  const [userStats, setUserStats] = useState(null);
  const [savedPlans, setSavedPlans] = useState([]);
  const [isConsultationActive, setIsConsultationActive] = useState(false);
  const [messages, setMessages] = useState([]);
  const [inputMessage, setInputMessage] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [questionNumber, setQuestionNumber] = useState(0);
  const [isComplete, setIsComplete] = useState(false);
  const [useProfileData, setUseProfileData] = useState(true);
  const [sessionId] = useState(() => crypto.randomUUID());
  const messagesEndRef = useRef(null);
  const navigate = useNavigate();

  // Fetch user profile and stats
  useEffect(() => {
    fetchUserData();
    fetchSavedPlans();
  }, []);

  const fetchUserData = async () => {
    try {
      const token = localStorage.getItem('token');
      const [profileRes, statsRes] = await Promise.all([
        fetch('/api/profile', {
          headers: { 'Authorization': `Bearer ${token}` }
        }),
        fetch('/api/dashboard-data', {
          headers: { 'Authorization': `Bearer ${token}` }
        })
      ]);

      if (profileRes.ok) {
        const profile = await profileRes.json();
        setUserProfile(profile);
      }

      if (statsRes.ok) {
        const stats = await statsRes.json();
        setUserStats(stats);
      }
    } catch (error) {
      console.error('Error fetching user data:', error);
    }
  };

  const fetchSavedPlans = async () => {
    try {
      const token = localStorage.getItem('token');
      const response = await fetch('/api/ai/plans', {
        headers: { 'Authorization': `Bearer ${token}` }
      });

      if (response.ok) {
        const plans = await response.json();
        setSavedPlans(plans);
      }
    } catch (error) {
      console.error('Error fetching saved plans:', error);
    }
  };

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const startConsultation = () => {
    setIsConsultationActive(true);
    setMessages([]);
    setQuestionNumber(0);
    setIsComplete(false);
    setInputMessage('');
    
    // Send initial message to start consultation
    sendMessage('', true);
  };

  const sendMessage = async (userMessage = '', isInitial = false) => {
    if (!isInitial && (!userMessage.trim() || isLoading)) return;

    if (!isInitial) {
      setInputMessage('');
      setIsLoading(true);

      // Add user message to chat
      setMessages(prev => [...prev, { 
        id: Date.now(), 
        text: userMessage.trim(), 
        isUser: true, 
        timestamp: new Date() 
      }]);
    }

    try {
      const token = localStorage.getItem('token');
      const response = await fetch('/api/ai/fitness-chat', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({
          message: userMessage,
          sessionId: sessionId,
          useProfileData: useProfileData,
          userProfile: userProfile,
          userStats: userStats
        })
      });

      if (!response.ok) {
        throw new Error('Failed to get AI response');
      }

      const data = await response.json();
      
      // Add AI response to chat
      setMessages(prev => [...prev, { 
        id: Date.now() + 1, 
        text: data.reply, 
        isUser: false, 
        timestamp: new Date() 
      }]);

      setQuestionNumber(data.questionNumber);
      setIsComplete(data.isComplete);

      if (data.isComplete) {
        // Save the plan
        await savePlan(data.plan, data.answers);
        // Refresh saved plans
        fetchSavedPlans();
      }

    } catch (error) {
      console.error('Error sending message:', error);
      setMessages(prev => [...prev, { 
        id: Date.now() + 1, 
        text: "Sorry, I encountered an error. Please try again.", 
        isUser: false, 
        timestamp: new Date() 
      }]);
    } finally {
      setIsLoading(false);
    }
  };

  const savePlan = async (plan, answers) => {
    try {
      const token = localStorage.getItem('token');
      await fetch('/api/ai/plans', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({
          plan,
          answers,
          userStatsSnapshot: {
            age: userProfile?.age,
            weight: userProfile?.weight_kg,
            height: userProfile?.height_cm,
            gender: userProfile?.sex,
            goal: answers[0] || 'Not specified'
          }
        })
      });
    } catch (error) {
      console.error('Error saving plan:', error);
    }
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage(inputMessage);
    }
  };

  const endConsultation = () => {
    setIsConsultationActive(false);
    setMessages([]);
    setQuestionNumber(0);
    setIsComplete(false);
    setInputMessage('');
  };

  const getUserName = () => {
    const token = localStorage.getItem('token');
    if (token) {
      try {
        const payload = JSON.parse(atob(token.split('.')[1]));
        return payload.name || 'User';
      } catch {
        return 'User';
      }
    }
    return 'User';
  };

  const formatDate = (dateString) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  if (isConsultationActive) {
    return (
      <div className="ai-coach-consultation">
        {/* Header */}
        <div className="consultation-header">
          <div className="consultation-title">
            <h2>AI Fitness Coach Consultation</h2>
            <p>Personalized fitness planning in progress</p>
          </div>
          <button onClick={endConsultation} className="end-consultation-btn">
            End Consultation
          </button>
        </div>

        {/* Progress Bar */}
        {!isComplete && questionNumber > 0 && (
          <div className="consultation-progress">
            <div className="progress-bar">
              <div 
                className="progress-fill" 
                style={{ width: `${(questionNumber / 5) * 100}%` }}
              ></div>
            </div>
            <span className="progress-text">Question {questionNumber} of 5</span>
          </div>
        )}

        <div className="consultation-content">
          {/* Chat Area */}
          <div className="chat-area">
            <div className="chat-messages">
              {messages.map((message) => (
                <div key={message.id} className={`message ${message.isUser ? 'user-message' : 'ai-message'}`}>
                  {!message.isUser && <div className="message-avatar">💪</div>}
                  <div className="message-content">
                    <div className="message-bubble">
                      {message.text}
                    </div>
                    <div className="message-time">
                      {message.timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                    </div>
                  </div>
                </div>
              ))}

              {/* Typing Indicator */}
              {isLoading && (
                <div className="message ai-message">
                  <div className="message-avatar">💪</div>
                  <div className="message-content">
                    <div className="message-bubble typing-indicator">
                      <span></span>
                      <span></span>
                      <span></span>
                    </div>
                  </div>
                </div>
              )}

              <div ref={messagesEndRef} />
            </div>

            {/* Input */}
            {!isComplete && (
              <div className="chat-input">
                <div className="input-container">
                  <input
                    type="text"
                    value={inputMessage}
                    onChange={(e) => setInputMessage(e.target.value)}
                    onKeyPress={handleKeyPress}
                    placeholder="Type your answer here..."
                    disabled={isLoading}
                    className="message-input"
                  />
                  <button
                    onClick={() => sendMessage(inputMessage)}
                    disabled={!inputMessage.trim() || isLoading}
                    className="send-button"
                  >
                    <span className="send-icon">→</span>
                  </button>
                </div>
              </div>
            )}

            {/* Completion Actions */}
            {isComplete && (
              <div className="completion-actions">
                <button onClick={startConsultation} className="action-btn primary">
                  Start New Consultation
                </button>
                <button onClick={endConsultation} className="action-btn secondary">
                  Back to AI Coach
                </button>
              </div>
            )}
          </div>

          {/* Sidebar */}
          <div className="consultation-sidebar">
            <div className="sidebar-section">
              <h3>Your Current Stats</h3>
              <div className="stats-grid">
                {userProfile?.age && <div className="stat-item">
                  <span className="stat-label">Age</span>
                  <span className="stat-value">{userProfile.age}</span>
                </div>}
                {userProfile?.weight_kg && <div className="stat-item">
                  <span className="stat-label">Weight</span>
                  <span className="stat-value">{userProfile.weight_kg} kg</span>
                </div>}
                {userProfile?.height_cm && <div className="stat-item">
                  <span className="stat-label">Height</span>
                  <span className="stat-value">{userProfile.height_cm} cm</span>
                </div>}
                {userProfile?.sex && <div className="stat-item">
                  <span className="stat-label">Gender</span>
                  <span className="stat-value">{userProfile.sex}</span>
                </div>}
              </div>
            </div>

            <div className="sidebar-section">
              <h3>Recent Activity</h3>
              <div className="activity-summary">
                {userStats && userStats.length > 0 ? (
                  userStats.slice(0, 3).map((stat, index) => (
                    <div key={index} className="activity-item">
                      <span className="activity-label">{stat.label}</span>
                      <span className="activity-value">{stat.value}</span>
                    </div>
                  ))
                ) : (
                  <p className="no-activity">No recent activity</p>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="ai-coach-page">
      {/* Navigation Header */}
      <div className="ai-coach-nav">
        <button className="back-btn" onClick={() => navigate('/dashboard')}>
          ← Back to Dashboard
        </button>
        <div className="nav-title">AI Fitness Coach</div>
        <div className="nav-spacer"></div>
      </div>

      <div className="ai-coach-header">
        <div className="header-content">
          <h1>AI Fitness Coach</h1>
          <p>Hi {getUserName()}, let's create your personalized fitness plan</p>
        </div>
        <div className="header-actions">
          <button onClick={startConsultation} className="start-consultation-btn">
            Start New Consultation
          </button>
        </div>
      </div>

      {/* Settings */}
      <div className="ai-coach-settings">
        <div className="settings-card">
          <h3>Personalization Settings</h3>
          <div className="setting-item">
            <label className="setting-label">
              <input
                type="checkbox"
                checked={useProfileData}
                onChange={(e) => setUseProfileData(e.target.checked)}
                className="setting-checkbox"
              />
              <span className="checkmark"></span>
              Use my profile data for personalized recommendations
            </label>
            <p className="setting-description">
              When enabled, I'll use your current stats, workout history, and nutrition logs to provide more accurate recommendations.
            </p>
          </div>
        </div>
      </div>

      {/* Saved Plans */}
      <div className="saved-plans-section">
        <h2>Your Saved Plans</h2>
        {savedPlans.length > 0 ? (
          <div className="plans-grid">
            {savedPlans.map((plan) => (
              <div key={plan._id} className="plan-card">
                <div className="plan-header">
                  <h3>Fitness Plan</h3>
                  <span className="plan-date">{formatDate(plan.createdAt)}</span>
                </div>
                <div className="plan-stats">
                  {plan.userStatsSnapshot && (
                    <div className="plan-stats-grid">
                      {plan.userStatsSnapshot.age && (
                        <span className="plan-stat">Age: {plan.userStatsSnapshot.age}</span>
                      )}
                      {plan.userStatsSnapshot.weight && (
                        <span className="plan-stat">Weight: {plan.userStatsSnapshot.weight}kg</span>
                      )}
                      {plan.userStatsSnapshot.goal && (
                        <span className="plan-stat">Goal: {plan.userStatsSnapshot.goal}</span>
                      )}
                    </div>
                  )}
                </div>
                <div className="plan-preview">
                  <p>{plan.plan.substring(0, 150)}...</p>
                </div>
                <div className="plan-actions">
                  <button className="plan-btn view-btn">View Details</button>
                  <button className="plan-btn apply-btn">Apply Plan</button>
                  <button className="plan-btn delete-btn">Delete</button>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="no-plans">
            <div className="no-plans-icon">📋</div>
            <h3>No saved plans yet</h3>
            <p>Start your first consultation to get a personalized fitness plan!</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default AICoach;
