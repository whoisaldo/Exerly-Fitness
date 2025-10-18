import React, { useState } from 'react';
import API_CONFIG from '../../config';
import './SavedPlans.css';

const { BASE_URL } = API_CONFIG;

const SavedPlans = ({ plans, onRefresh, creditsRemaining }) => {
  const [selectedPlan, setSelectedPlan] = useState(null);
  const [showModal, setShowModal] = useState(false);

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

  const handleViewPlan = (plan) => {
    setSelectedPlan(plan);
    setShowModal(true);
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
        onRefresh();
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
        onRefresh();
        alert('Plan deleted successfully!');
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

  if (plans.length === 0) {
    return (
      <div className="no-plans">
        <div className="no-plans-icon">📋</div>
        <h3>No saved plans yet</h3>
        <p>Use the quick actions above to get your first AI-generated plan!</p>
      </div>
    );
  }

  return (
    <div className="saved-plans">
      <div className="plans-grid">
        {plans.map((plan) => (
          <div key={plan._id} className="plan-card">
            <div className="plan-header">
              <div className="plan-type">
                <span className="plan-icon">{getTypeIcon(plan.type)}</span>
                <span className="plan-type-title">{getTypeTitle(plan.type)}</span>
              </div>
              <span className="plan-date">{formatDate(plan.createdAt)}</span>
            </div>
            
            <div className="plan-preview">
              <p>{plan.response.substring(0, 150)}...</p>
            </div>
            
            <div className="plan-actions">
              <button 
                className="plan-btn view-btn" 
                onClick={() => handleViewPlan(plan)}
              >
                View Details
              </button>
              <button 
                className="plan-btn apply-btn" 
                onClick={() => handleApplyPlan(plan)}
                disabled={plan.applied}
              >
                {plan.applied ? 'Applied' : 'Apply Plan'}
              </button>
              <button 
                className="plan-btn delete-btn" 
                onClick={() => handleDeletePlan(plan._id)}
              >
                Delete
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* Plan Details Modal */}
      {showModal && selectedPlan && (
        <div className="plan-modal-overlay" onClick={() => setShowModal(false)}>
          <div className="plan-modal" onClick={(e) => e.stopPropagation()}>
            <div className="plan-modal-header">
              <div className="plan-modal-title">
                <span className="plan-modal-icon">{getTypeIcon(selectedPlan.type)}</span>
                <h2>{getTypeTitle(selectedPlan.type)}</h2>
              </div>
              <button 
                className="close-modal-btn" 
                onClick={() => setShowModal(false)}
              >
                ×
              </button>
            </div>
            
            <div className="plan-modal-content">
              <div className="plan-modal-meta">
                <span className="plan-modal-date">Created: {formatDate(selectedPlan.createdAt)}</span>
                {selectedPlan.applied && (
                  <span className="plan-applied-badge">✓ Applied</span>
                )}
              </div>
              
              <div className="plan-modal-response">
                <h3>AI Response</h3>
                <div className="plan-content">
                  {selectedPlan.response.split('\n').map((line, index) => (
                    <p key={index} className="plan-line">
                      {line}
                    </p>
                  ))}
                </div>
              </div>
            </div>
            
            <div className="plan-modal-actions">
              <button 
                className="plan-btn apply-btn" 
                onClick={() => {
                  handleApplyPlan(selectedPlan);
                  setShowModal(false);
                }}
                disabled={selectedPlan.applied}
              >
                {selectedPlan.applied ? 'Already Applied' : 'Apply This Plan'}
              </button>
              <button 
                className="plan-btn delete-btn" 
                onClick={() => {
                  handleDeletePlan(selectedPlan._id);
                  setShowModal(false);
                }}
              >
                Delete Plan
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default SavedPlans;
