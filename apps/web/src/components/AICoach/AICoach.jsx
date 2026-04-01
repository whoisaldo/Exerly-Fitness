// frontend/src/components/AICoach/AICoach.jsx
import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { GlassCard, PageTransition, ActionButton, Badge, EmptyState, PageHeader } from '../ui';
import API_CONFIG from '../../config';

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

  // Response modal state (replaces old DOM manipulation)
  const [responseModal, setResponseModal] = useState({ open: false, content: '', type: '' });

  // Saved plan detail modal state
  const [planModal, setPlanModal] = useState({ open: false, plan: null });

  // Custom question state
  const [question, setQuestion] = useState('');
  const [isQuestionExpanded, setIsQuestionExpanded] = useState(false);

  // Credit countdown state
  const [timeLeft, setTimeLeft] = useState(credits.hourly.resetTime);

  useEffect(() => {
    fetchUserProfile();
    fetchCredits();
    fetchSavedPlans();
  }, []);

  // Countdown timer for credits
  useEffect(() => {
    const [minutes, seconds] = credits.hourly.resetTime.split(':').map(Number);
    let totalSeconds = (minutes || 0) * 60 + (seconds || 0);

    const timer = setInterval(() => {
      if (totalSeconds <= 0) {
        setTimeLeft('0:00');
        fetchCredits();
        clearInterval(timer);
        return;
      }

      totalSeconds--;
      const mins = Math.floor(totalSeconds / 60);
      const secs = totalSeconds % 60;
      setTimeLeft(`${mins}:${secs.toString().padStart(2, '0')}`);
    }, 1000);

    return () => clearInterval(timer);
  }, [credits.hourly.resetTime]);

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

  const handleQuickAction = async (type, customQuestion) => {
    if (credits.hourly.remaining <= 0) {
      alert('You have no hourly credits remaining. Please wait for the next reset.');
      return;
    }

    setIsLoading(true);

    try {
      const token = localStorage.getItem('token');
      const body = { type, includeContext: true };
      if (customQuestion) body.question = customQuestion;

      const response = await fetch(`${BASE_URL}/api/ai/coach`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(body)
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

      // Show the response in a modal (React state instead of DOM manipulation)
      showAIResponse(data.response, type);

    } catch (error) {
      console.error('Error with quick action:', error);
      alert('Error getting AI response. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  const showAIResponse = (response, type) => {
    setResponseModal({ open: true, content: response, type });
  };

  // Saved plans helper functions
  const formatDate = (dateString) => {
    if (!dateString) return 'Unknown Date';
    try {
      return new Date(dateString).toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      });
    } catch (error) {
      return 'Invalid Date';
    }
  };

  const handleApplyPlan = async (plan) => {
    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`${BASE_URL}/api/ai/plans/${plan._id}/apply`, {
        method: 'PATCH',
        headers: { 'Authorization': `Bearer ${token}` }
      });

      if (response.ok) {
        alert('Plan applied successfully!');
        fetchSavedPlans();
      } else {
        alert('Error applying plan');
      }
    } catch (error) {
      console.error('Error applying plan:', error);
      alert('Error applying plan');
    }
  };

  const handleDeletePlan = async (planId) => {
    if (!window.confirm('Are you sure you want to delete this plan?')) return;

    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`${BASE_URL}/api/ai/plans/${planId}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });

      if (response.ok) {
        fetchSavedPlans();
        setPlanModal({ open: false, plan: null });
      } else {
        alert('Error deleting plan');
      }
    } catch (error) {
      console.error('Error deleting plan:', error);
      alert('Error deleting plan');
    }
  };

  const getTypeIcon = (type) => {
    switch (type) {
      case 'workout_plan': return '🏋️';
      case 'nutrition_advice': return '🍎';
      case 'progress_analysis': return '📊';
      case 'custom_question': return '💬';
      default: return '📋';
    }
  };

  const getTypeTitle = (type) => {
    switch (type) {
      case 'workout_plan': return 'Workout Plan';
      case 'nutrition_advice': return 'Nutrition Advice';
      case 'progress_analysis': return 'Progress Analysis';
      case 'custom_question': return 'Custom Question';
      default: return 'AI Plan';
    }
  };

  const getCreditStatus = () => {
    if (credits.hourly.remaining >= 3) return 'good';
    if (credits.hourly.remaining >= 1) return 'warning';
    return 'critical';
  };

  const creditStatus = getCreditStatus();
  const statusColorMap = {
    good: 'text-success',
    warning: 'text-warning',
    critical: 'text-error',
  };
  const statusBorderMap = {
    good: 'border-success/30',
    warning: 'border-warning/30',
    critical: 'border-error/30',
  };
  const statusBgMap = {
    good: 'bg-success/5',
    warning: 'bg-warning/5',
    critical: 'bg-error/5',
  };

  // Custom question handlers
  const handleCustomSubmit = (e) => {
    e.preventDefault();
    if (!question.trim()) {
      alert('Please enter a question');
      return;
    }
    if (credits.hourly.remaining <= 0) {
      alert('You have no hourly credits remaining. Please wait for the next reset.');
      return;
    }
    handleQuickAction('custom_question', question);
    setQuestion('');
    setIsQuestionExpanded(false);
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleCustomSubmit(e);
    }
  };

  const exampleQuestions = [
    "How can I improve my squat form?",
    "What should I eat before a workout?",
    "How often should I rest between sets?",
    "What's the best way to build muscle?",
    "How can I stay motivated to work out?"
  ];

  const quickActions = [
    {
      id: 'workout_plan',
      icon: '🏋️',
      title: 'Workout Plan',
      description: 'Get a personalized workout plan based on your goals',
      gradient: 'from-primary/20 to-primary/5',
    },
    {
      id: 'nutrition_advice',
      icon: '🍎',
      title: 'Nutrition Advice',
      description: 'Get personalized nutrition guidance',
      gradient: 'from-success/20 to-success/5',
    },
    {
      id: 'progress_analysis',
      icon: '📊',
      title: 'Progress Analysis',
      description: 'Analyze your fitness progress and trends',
      gradient: 'from-warning/20 to-warning/5',
    }
  ];

  return (
    <PageTransition>
      <div className="min-h-screen bg-deep px-4 py-6 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="max-w-7xl mx-auto mb-8">
          <button
            onClick={() => navigate('/dashboard')}
            className="inline-flex items-center gap-2 text-white/50 hover:text-white transition-colors mb-6 h-11 px-3 -ml-3 rounded-xl"
          >
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
            </svg>
            Back to Dashboard
          </button>

          <PageHeader
            title="AI Fitness Coach"
            subtitle="Get personalized fitness advice powered by AI"
          />
        </div>

        <div className="max-w-7xl mx-auto flex flex-col lg:flex-row gap-6">
          {/* Left Sidebar */}
          <div className="w-full lg:w-80 shrink-0 space-y-6">
            {/* Credit Badge */}
            <GlassCard elevated className={`p-5 border ${statusBorderMap[creditStatus]} ${statusBgMap[creditStatus]}`}>
              <div className="flex items-center gap-3 mb-4">
                <div className={`w-10 h-10 rounded-xl bg-gradient-primary flex items-center justify-center shadow-glow-sm`}>
                  <span className="text-lg">💬</span>
                </div>
                <div>
                  <h3 className="text-white font-semibold text-sm">AI Credits</h3>
                  <p className="text-white/40 text-xs">Usage this period</p>
                </div>
              </div>

              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-white/50 text-sm">Hourly</span>
                  <span className={`font-bold text-lg ${statusColorMap[creditStatus]}`}>
                    {credits.hourly.remaining}/5
                  </span>
                </div>
                <div className="w-full h-1.5 rounded-full bg-white/5 overflow-hidden">
                  <div
                    className={`h-full rounded-full transition-all duration-500 ${
                      creditStatus === 'good' ? 'bg-success' : creditStatus === 'warning' ? 'bg-warning' : 'bg-error'
                    }`}
                    style={{ width: `${(credits.hourly.remaining / 5) * 100}%` }}
                  />
                </div>

                <div className="flex items-center justify-between">
                  <span className="text-white/50 text-sm">Daily</span>
                  <span className="text-white/70 font-medium text-sm">{credits.daily.used}/20</span>
                </div>
                <div className="w-full h-1.5 rounded-full bg-white/5 overflow-hidden">
                  <div
                    className="h-full rounded-full bg-primary/60 transition-all duration-500"
                    style={{ width: `${(credits.daily.used / 20) * 100}%` }}
                  />
                </div>

                {credits.hourly.remaining === 0 && (
                  <div className="mt-2 pt-3 border-t border-border-subtle">
                    <div className="flex items-center gap-2 text-warning text-xs">
                      <svg className="w-3.5 h-3.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      <span>Resets in {timeLeft}</span>
                    </div>
                  </div>
                )}

                {credits.daily.used >= 20 && (
                  <div className="mt-2 pt-3 border-t border-border-subtle text-center">
                    <p className="text-error text-xs font-medium">Daily limit reached</p>
                    <p className="text-white/30 text-xs mt-1">Resets at {credits.daily.resetTime}</p>
                  </div>
                )}
              </div>
            </GlassCard>

            {/* Quick Actions */}
            <div>
              <h3 className="text-label text-white/50 mb-3 px-1">Quick Actions</h3>
              <div className="space-y-3">
                {quickActions.map((action) => (
                  <GlassCard
                    key={action.id}
                    hover
                    className={`p-4 cursor-pointer transition-all group ${
                      credits.hourly.remaining <= 0 ? 'opacity-50 pointer-events-none' : ''
                    }`}
                    as="button"
                    onClick={() => handleQuickAction(action.id)}
                  >
                    <div className="flex items-start gap-3">
                      <div className={`w-10 h-10 rounded-xl bg-gradient-to-br ${action.gradient} flex items-center justify-center shrink-0`}>
                        <span className="text-lg">{action.icon}</span>
                      </div>
                      <div className="text-left min-w-0">
                        <h4 className="text-white text-sm font-medium group-hover:text-primary-bright transition-colors">
                          {action.title}
                        </h4>
                        <p className="text-white/40 text-xs mt-0.5 leading-relaxed">{action.description}</p>
                      </div>
                    </div>
                    {isLoading && (
                      <div className="mt-3 flex justify-center">
                        <div className="h-4 w-4 animate-spin rounded-full border-2 border-primary border-t-transparent" />
                      </div>
                    )}
                  </GlassCard>
                ))}
              </div>
            </div>

            {/* Saved Plans */}
            <div>
              <h3 className="text-label text-white/50 mb-3 px-1">
                Saved Plans ({savedPlans.length})
              </h3>
              <div className="space-y-2 max-h-[400px] overflow-y-auto pr-1 scrollbar-thin scrollbar-thumb-white/10 scrollbar-track-transparent">
                {savedPlans.length === 0 ? (
                  <GlassCard className="p-5">
                    <EmptyState
                      icon={
                        <svg className="w-8 h-8 text-white/20" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                          <path strokeLinecap="round" strokeLinejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                        </svg>
                      }
                      title="No saved plans yet"
                      message="Use the quick actions to get your first AI plan!"
                    />
                  </GlassCard>
                ) : (
                  savedPlans.map((plan) => (
                    <GlassCard
                      key={plan._id}
                      hover
                      className="p-3.5 cursor-pointer group"
                      onClick={() => setPlanModal({ open: true, plan })}
                    >
                      <div className="flex items-start gap-3">
                        <span className="text-base mt-0.5">{getTypeIcon(plan.type)}</span>
                        <div className="min-w-0 flex-1">
                          <div className="flex items-center justify-between gap-2 mb-1">
                            <h4 className="text-white text-xs font-medium truncate group-hover:text-primary-bright transition-colors">
                              {getTypeTitle(plan.type)}
                            </h4>
                            {plan.applied && (
                              <Badge variant="status" className="text-[10px] shrink-0">Applied</Badge>
                            )}
                          </div>
                          <p className="text-white/30 text-xs leading-relaxed line-clamp-2">
                            {plan.response?.substring(0, 100)}...
                          </p>
                          <p className="text-white/20 text-[10px] mt-1.5">{formatDate(plan.createdAt)}</p>
                        </div>
                      </div>
                    </GlassCard>
                  ))
                )}
              </div>
            </div>
          </div>

          {/* Right Main Area */}
          <div className="flex-1 min-w-0 space-y-6">
            {/* Custom Question */}
            <GlassCard className="p-6">
              <div className="mb-5">
                <h2 className="text-lg font-semibold text-white">Ask Your Coach</h2>
                <p className="text-white/40 text-sm mt-1">
                  Get personalized advice based on your profile and goals
                </p>
              </div>

              <form onSubmit={handleCustomSubmit}>
                <div className="relative">
                  <textarea
                    value={question}
                    onChange={(e) => setQuestion(e.target.value)}
                    onKeyPress={handleKeyPress}
                    placeholder="Type your question here..."
                    rows={isQuestionExpanded ? 4 : 2}
                    disabled={isLoading || credits.hourly.remaining <= 0}
                    onFocus={() => setIsQuestionExpanded(true)}
                    onBlur={() => {
                      if (!question.trim()) setIsQuestionExpanded(false);
                    }}
                    className="w-full bg-surface-2 border border-border-subtle rounded-xl px-4 py-3 text-white placeholder-white/30 outline-none focus:border-primary/50 focus:ring-1 focus:ring-primary/25 transition-colors resize-none disabled:opacity-40"
                  />
                </div>

                <div className="flex items-center justify-between mt-4">
                  {credits.hourly.remaining <= 0 && (
                    <p className="text-warning text-xs">No credits remaining. Resets soon.</p>
                  )}
                  <div className="ml-auto">
                    <ActionButton
                      variant="primary"
                      loading={isLoading}
                      icon={
                        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <path strokeLinecap="round" strokeLinejoin="round" d="M13 10V3L4 14h7v7l9-11h-7z" />
                        </svg>
                      }
                    >
                      Ask Coach
                    </ActionButton>
                  </div>
                </div>
              </form>

              {/* Example Questions */}
              {!isQuestionExpanded && (
                <div className="mt-6 pt-5 border-t border-border-subtle">
                  <p className="text-label text-white/40 mb-3">Try asking about:</p>
                  <div className="flex flex-wrap gap-2">
                    {exampleQuestions.map((example, index) => (
                      <button
                        key={index}
                        onClick={() => {
                          setQuestion(example);
                          setIsQuestionExpanded(true);
                        }}
                        disabled={credits.hourly.remaining <= 0}
                        className="inline-flex items-center px-3 py-1.5 rounded-full text-xs text-white/60 bg-surface-2 border border-border-subtle hover:border-primary/30 hover:text-white/80 transition-colors disabled:opacity-30 disabled:pointer-events-none h-8"
                      >
                        {example}
                      </button>
                    ))}
                  </div>
                </div>
              )}
            </GlassCard>

            {/* Plans grid for larger screens */}
            {savedPlans.length > 0 && (
              <div className="hidden lg:block">
                <h3 className="text-label text-white/50 mb-4">Recent Plans</h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {savedPlans.slice(0, 4).map((plan) => (
                    <GlassCard
                      key={plan._id}
                      hover
                      className="p-5 cursor-pointer group"
                      onClick={() => setPlanModal({ open: true, plan })}
                    >
                      <div className="flex items-center gap-3 mb-3">
                        <div className="w-9 h-9 rounded-lg bg-surface-2 flex items-center justify-center">
                          <span className="text-base">{getTypeIcon(plan.type)}</span>
                        </div>
                        <div className="flex-1 min-w-0">
                          <h4 className="text-white text-sm font-medium truncate group-hover:text-primary-bright transition-colors">
                            {getTypeTitle(plan.type)}
                          </h4>
                          <p className="text-white/30 text-xs">{formatDate(plan.createdAt)}</p>
                        </div>
                        {plan.applied && (
                          <Badge variant="status">Applied</Badge>
                        )}
                      </div>
                      <p className="text-white/40 text-sm leading-relaxed line-clamp-3">
                        {plan.response?.substring(0, 200)}...
                      </p>
                    </GlassCard>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>

        {/* AI Response Modal */}
        <AnimatePresence>
          {responseModal.open && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm"
              onClick={() => setResponseModal({ open: false, content: '', type: '' })}
            >
              <motion.div
                initial={{ opacity: 0, scale: 0.95, y: 20 }}
                animate={{ opacity: 1, scale: 1, y: 0 }}
                exit={{ opacity: 0, scale: 0.95, y: 20 }}
                transition={{ type: 'spring', damping: 25, stiffness: 300 }}
                onClick={(e) => e.stopPropagation()}
                className="w-full max-w-2xl max-h-[80vh] flex flex-col"
              >
                <GlassCard elevated className="flex flex-col overflow-hidden">
                  {/* Modal Header */}
                  <div className="flex items-center justify-between px-6 py-4 border-b border-border-subtle shrink-0">
                    <h3 className="text-white font-semibold">
                      AI {responseModal.type.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase())}
                    </h3>
                    <button
                      onClick={() => setResponseModal({ open: false, content: '', type: '' })}
                      className="w-8 h-8 rounded-lg flex items-center justify-center text-white/40 hover:text-white hover:bg-white/5 transition-colors"
                    >
                      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  </div>

                  {/* Modal Body */}
                  <div className="px-6 py-5 overflow-y-auto flex-1">
                    <div className="text-white/80 text-sm leading-relaxed whitespace-pre-wrap">
                      {responseModal.content}
                    </div>
                  </div>

                  {/* Modal Footer */}
                  <div className="px-6 py-4 border-t border-border-subtle shrink-0 flex justify-end">
                    <ActionButton
                      variant="primary"
                      onClick={() => setResponseModal({ open: false, content: '', type: '' })}
                    >
                      Got it!
                    </ActionButton>
                  </div>
                </GlassCard>
              </motion.div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Plan Detail Modal */}
        <AnimatePresence>
          {planModal.open && planModal.plan && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm"
              onClick={() => setPlanModal({ open: false, plan: null })}
            >
              <motion.div
                initial={{ opacity: 0, scale: 0.95, y: 20 }}
                animate={{ opacity: 1, scale: 1, y: 0 }}
                exit={{ opacity: 0, scale: 0.95, y: 20 }}
                transition={{ type: 'spring', damping: 25, stiffness: 300 }}
                onClick={(e) => e.stopPropagation()}
                className="w-full max-w-2xl max-h-[80vh] flex flex-col"
              >
                <GlassCard elevated className="flex flex-col overflow-hidden">
                  {/* Modal Header */}
                  <div className="flex items-center justify-between px-6 py-4 border-b border-border-subtle shrink-0">
                    <div className="flex items-center gap-3">
                      <span className="text-xl">{getTypeIcon(planModal.plan.type)}</span>
                      <div>
                        <h3 className="text-white font-semibold">{getTypeTitle(planModal.plan.type)}</h3>
                        <p className="text-white/30 text-xs mt-0.5">{formatDate(planModal.plan.createdAt)}</p>
                      </div>
                    </div>
                    <div className="flex items-center gap-2">
                      {planModal.plan.applied && (
                        <Badge variant="status">Applied</Badge>
                      )}
                      <button
                        onClick={() => setPlanModal({ open: false, plan: null })}
                        className="w-8 h-8 rounded-lg flex items-center justify-center text-white/40 hover:text-white hover:bg-white/5 transition-colors"
                      >
                        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                        </svg>
                      </button>
                    </div>
                  </div>

                  {/* Modal Body */}
                  <div className="px-6 py-5 overflow-y-auto flex-1">
                    <div className="text-white/80 text-sm leading-relaxed">
                      {planModal.plan.response.split('\n').map((line, index) => (
                        <p key={index} className={line.trim() === '' ? 'h-3' : 'mb-1.5'}>{line}</p>
                      ))}
                    </div>
                  </div>

                  {/* Modal Footer */}
                  <div className="px-6 py-4 border-t border-border-subtle shrink-0 flex items-center justify-between">
                    <button
                      onClick={() => {
                        handleDeletePlan(planModal.plan._id);
                      }}
                      className="h-11 px-4 rounded-xl text-sm font-medium text-error/70 hover:text-error hover:bg-error/10 transition-colors"
                    >
                      Delete
                    </button>
                    <ActionButton
                      variant="primary"
                      onClick={() => {
                        handleApplyPlan(planModal.plan);
                        setPlanModal({ open: false, plan: null });
                      }}
                    >
                      {planModal.plan.applied ? 'Already Applied' : 'Apply Plan'}
                    </ActionButton>
                  </div>
                </GlassCard>
              </motion.div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </PageTransition>
  );
};

export default AICoach;
