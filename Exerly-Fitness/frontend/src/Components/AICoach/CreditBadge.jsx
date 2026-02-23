import React, { useState, useEffect } from 'react';
import './CreditBadge.css';

const CreditBadge = ({ credits, onRefresh }) => {
  const [timeLeft, setTimeLeft] = useState(credits.hourly.resetTime);

  useEffect(() => {
    // Parse the reset time and start countdown
    const [minutes, seconds] = credits.hourly.resetTime.split(':').map(Number);
    let totalSeconds = minutes * 60 + seconds;
    
    const timer = setInterval(() => {
      if (totalSeconds <= 0) {
        setTimeLeft('0:00');
        onRefresh(); // Refresh credits when timer hits zero
        clearInterval(timer);
        return;
      }
      
      totalSeconds--;
      const mins = Math.floor(totalSeconds / 60);
      const secs = totalSeconds % 60;
      setTimeLeft(`${mins}:${secs.toString().padStart(2, '0')}`);
    }, 1000);

    return () => clearInterval(timer);
  }, [credits.hourly.resetTime, onRefresh]);

  const getCreditStatus = () => {
    if (credits.hourly.remaining >= 3) {
      return 'good';
    } else if (credits.hourly.remaining >= 1) {
      return 'warning';
    } else {
      return 'critical';
    }
  };

  const status = getCreditStatus();

  return (
    <div className={`credit-badge ${status}`}>
      <div className="credit-info">
        <div className="hourly-credits">
          <span className="credit-icon">💬</span>
          <span className="credit-count">{credits.hourly.remaining}/5</span>
          {credits.hourly.remaining === 0 && (
            <span className="reset-timer">⏰ {timeLeft}</span>
          )}
        </div>
        <div className="daily-credits">
          <span className="daily-count">{credits.daily.used}/20 today</span>
        </div>
      </div>
      
      {credits.hourly.remaining === 0 && (
        <div className="limit-message">
          <p>⏰ You've used your 5 questions this hour</p>
          <p>Next question available in: {timeLeft}</p>
          <p>You've used {credits.daily.used}/20 questions today</p>
        </div>
      )}
      
      {credits.daily.used >= 20 && (
        <div className="daily-limit-message">
          <p>🚫 Daily AI Limit Reached</p>
          <p>You've used all 20 AI questions today! 🎉</p>
          <p>AI models are expensive to run 💸</p>
          <p>Exerly Fitness is completely free to use, but AI costs add up quickly.</p>
          <p>Your questions reset at midnight ({credits.daily.resetTime})</p>
        </div>
      )}
    </div>
  );
};

export default CreditBadge;
