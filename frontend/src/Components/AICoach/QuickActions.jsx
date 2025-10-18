import React from 'react';
import './QuickActions.css';

const QuickActions = ({ onAction, isLoading, creditsRemaining }) => {
  const actions = [
    {
      id: 'workout_plan',
      icon: '🏋️',
      title: 'Workout Plan',
      description: 'Get a personalized workout plan',
      color: '#8b5cf6'
    },
    {
      id: 'nutrition_advice',
      icon: '🍎',
      title: 'Nutrition Advice',
      description: 'Get personalized nutrition guidance',
      color: '#10b981'
    },
    {
      id: 'progress_analysis',
      icon: '📊',
      title: 'Progress Analysis',
      description: 'Analyze your fitness progress',
      color: '#f59e0b'
    }
  ];

  const handleActionClick = (actionId) => {
    if (creditsRemaining <= 0) {
      alert('You have no hourly credits remaining. Please wait for the next reset.');
      return;
    }
    onAction(actionId);
  };

  return (
    <div className="quick-actions">
      {actions.map((action) => (
        <div
          key={action.id}
          className={`action-card ${creditsRemaining <= 0 ? 'disabled' : ''}`}
          onClick={() => handleActionClick(action.id)}
          style={{ '--action-color': action.color }}
        >
          <div className="action-icon">{action.icon}</div>
          <div className="action-content">
            <h3>{action.title}</h3>
            <p>{action.description}</p>
            {creditsRemaining <= 0 && (
              <span className="no-credits">No credits remaining</span>
            )}
          </div>
          {isLoading && (
            <div className="loading-overlay">
              <div className="spinner"></div>
            </div>
          )}
        </div>
      ))}
    </div>
  );
};

export default QuickActions;
