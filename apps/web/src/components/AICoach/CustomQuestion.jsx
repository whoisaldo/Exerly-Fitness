import React, { useState } from 'react';
import './CustomQuestion.css';

const CustomQuestion = ({ onQuestion, isLoading, creditsRemaining }) => {
  const [question, setQuestion] = useState('');
  const [isExpanded, setIsExpanded] = useState(false);

  const handleSubmit = (e) => {
    e.preventDefault();
    
    if (!question.trim()) {
      alert('Please enter a question');
      return;
    }
    
    if (creditsRemaining <= 0) {
      alert('You have no hourly credits remaining. Please wait for the next reset.');
      return;
    }
    
    onQuestion('custom_question', question);
    setQuestion('');
    setIsExpanded(false);
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit(e);
    }
  };

  const exampleQuestions = [
    "How can I improve my squat form?",
    "What should I eat before a workout?",
    "How often should I rest between sets?",
    "What's the best way to build muscle?",
    "How can I stay motivated to work out?"
  ];

  return (
    <div className="custom-question">
      <div className="question-header">
        <h3>Ask me anything about fitness, nutrition, or form...</h3>
        <p>Get personalized advice based on your profile</p>
      </div>

      <form onSubmit={handleSubmit} className="question-form">
        <div className="input-container">
          <textarea
            value={question}
            onChange={(e) => setQuestion(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder="Type your question here..."
            className="question-input"
            rows={isExpanded ? 4 : 2}
            disabled={isLoading || creditsRemaining <= 0}
            onFocus={() => setIsExpanded(true)}
            onBlur={() => {
              if (!question.trim()) {
                setIsExpanded(false);
              }
            }}
          />
          <button
            type="submit"
            className="ask-button"
            disabled={!question.trim() || isLoading || creditsRemaining <= 0}
          >
            {isLoading ? (
              <div className="button-spinner"></div>
            ) : (
              'Ask Coach'
            )}
          </button>
        </div>
        
        {creditsRemaining <= 0 && (
          <div className="no-credits-message">
            ⏰ No credits remaining. Next question available after reset.
          </div>
        )}
      </form>

      {!isExpanded && (
        <div className="example-questions">
          <p className="examples-label">Example questions:</p>
          <div className="examples-grid">
            {exampleQuestions.map((example, index) => (
              <button
                key={index}
                className="example-question"
                onClick={() => {
                  setQuestion(example);
                  setIsExpanded(true);
                }}
                disabled={creditsRemaining <= 0}
              >
                {example}
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

export default CustomQuestion;
