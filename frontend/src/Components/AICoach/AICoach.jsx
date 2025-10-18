import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import API_CONFIG from '../../config';
import CreditBadge from './CreditBadge';
import QuickActions from './QuickActions';
import SavedPlans from './SavedPlans';
import CustomQuestion from './CustomQuestion';
import './AICoach.css';

const { BASE_URL } = API_CONFIG;

const AICoach = () => {
  const [userProfile, setUserProfile] = useState(null);
  const [credits, setCredits] = useState({
    hourly: { remaining: 5, limit: 5, resetTime: '0:00' },
    daily: { used: 0, limit: 20, resetTime: '0h 0m' }
  });
  const [savedPlans, setSavedPlans] = useState([]);
  const [isLoading, setIsLoading] = useState(false);
  const navigate = useNavigate();

  useEffect(() => {
    fetchUserProfile();
    fetchCredits();
    fetchSavedPlans();
  }, []);

  const fetchUserProfile = async () => {
    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`${BASE_URL}/api/profile`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      
      if (response.ok) {
        const data = await response.json();
        setUserProfile(data);
      }
    } catch (error) {
      console.error('Error fetching profile:', error);
    }
  };

  const fetchCredits = async () => {
    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`${BASE_URL}/api/ai/credits`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      
      if (response.ok) {
        const data = await response.json();
        setCredits(data);
      }
    } catch (error) {
      console.error('Error fetching credits:', error);
    }
  };

  const fetchSavedPlans = async () => {
    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`${BASE_URL}/api/ai/plans`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      
      if (response.ok) {
        const data = await response.json();
        setSavedPlans(data);
      }
    } catch (error) {
      console.error('Error fetching saved plans:', error);
    }
  };

  const handleQuickAction = async (type) => {
    if (credits.hourly.remaining <= 0) {
      alert('You have no hourly credits remaining. Please wait for the next reset.');
      return;
    }

    setIsLoading(true);
    
    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`${BASE_URL}/api/ai/coach`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({
          type,
          includeContext: true
        })
      });

      if (!response.ok) {
        const errorData = await response.json();
        if (errorData.error === 'Hourly limit reached') {
          alert(`Hourly limit reached. Next question available in ${errorData.waitTime}`);
          fetchCredits();
          return;
        } else if (errorData.error === 'Daily limit reached') {
          alert(`Daily limit reached. Resets at ${errorData.resetTime}`);
          fetchCredits();
          return;
        }
        throw new Error(errorData.error || 'Failed to get AI response');
      }

      const data = await response.json();
      
      // Update credits
      setCredits(prev => ({
        ...prev,
        hourly: { ...prev.hourly, remaining: data.creditsRemaining },
        daily: { ...prev.daily, used: data.dailyUsed }
      }));
      
      // Refresh saved plans
      fetchSavedPlans();
      
      // Show the response in a modal or new page
      showAIResponse(data.response, type);
      
    } catch (error) {
      console.error('Error with quick action:', error);
      alert('Error getting AI response. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  const showAIResponse = (response, type) => {
    // Create a modal to show the AI response
    const modal = document.createElement('div');
    modal.className = 'ai-response-modal';
    modal.innerHTML = `
      <div class="ai-response-content">
        <div class="ai-response-header">
          <h3>AI ${type.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase())}</h3>
          <button class="close-modal" onclick="this.closest('.ai-response-modal').remove()">×</button>
        </div>
        <div class="ai-response-body">
          <div class="ai-response-text">${response.replace(/\n/g, '<br>')}</div>
        </div>
        <div class="ai-response-actions">
          <button class="btn-primary" onclick="this.closest('.ai-response-modal').remove()">Got it!</button>
        </div>
      </div>
    `;
    
    document.body.appendChild(modal);
    
    // Add styles
    const style = document.createElement('style');
    style.textContent = `
      .ai-response-modal {
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: rgba(0, 0, 0, 0.8);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 1000;
        padding: 20px;
      }
      .ai-response-content {
        background: #1a1a2e;
        border-radius: 16px;
        max-width: 600px;
        width: 100%;
        max-height: 80vh;
        overflow-y: auto;
        border: 1px solid rgba(255, 255, 255, 0.1);
      }
      .ai-response-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 20px;
        border-bottom: 1px solid rgba(255, 255, 255, 0.1);
      }
      .ai-response-header h3 {
        color: #ffffff;
        margin: 0;
        font-size: 1.3rem;
      }
      .close-modal {
        background: none;
        border: none;
        color: #a0a0a0;
        font-size: 1.5rem;
        cursor: pointer;
        padding: 5px;
      }
      .ai-response-body {
        padding: 20px;
      }
      .ai-response-text {
        color: #ffffff;
        line-height: 1.6;
        white-space: pre-wrap;
      }
      .ai-response-actions {
        padding: 20px;
        border-top: 1px solid rgba(255, 255, 255, 0.1);
        text-align: right;
      }
      .btn-primary {
        background: linear-gradient(135deg, #8b5cf6, #a855f7);
        color: #ffffff;
        border: none;
        padding: 12px 24px;
        border-radius: 8px;
        cursor: pointer;
        font-weight: 600;
      }
    `;
    document.head.appendChild(style);
  };

  return (
    <div className="ai-coach-page">
      {/* Header */}
      <div className="ai-coach-header">
        <div className="header-content">
          <h1>AI Fitness Coach</h1>
          <p>Get personalized fitness advice powered by AI</p>
        </div>
        <CreditBadge credits={credits} onRefresh={fetchCredits} />
      </div>

      {/* Quick Actions */}
      <div className="quick-actions-section">
        <h2>Quick Actions</h2>
        <QuickActions 
          onAction={handleQuickAction}
          isLoading={isLoading}
          creditsRemaining={credits.hourly.remaining}
        />
      </div>

      {/* Saved Plans */}
      <div className="saved-plans-section">
        <h2>Your Saved Plans ({savedPlans.length})</h2>
        <SavedPlans 
          plans={savedPlans}
          onRefresh={fetchSavedPlans}
          creditsRemaining={credits.hourly.remaining}
        />
      </div>

      {/* Custom Question */}
      <div className="custom-question-section">
        <h2>Custom Question</h2>
        <CustomQuestion 
          onQuestion={handleQuickAction}
          isLoading={isLoading}
          creditsRemaining={credits.hourly.remaining}
        />
      </div>
    </div>
  );
};

export default AICoach;
