import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import API_CONFIG from '../../config';
import { GlassCard, ActionButton, PageTransition } from '../ui';

const { BASE_URL } = API_CONFIG;

const Onboarding = () => {
  const [currentStep, setCurrentStep] = useState(1);
  const [formData, setFormData] = useState({
    age: '',
    gender: '',
    height: '',
    weight: '',
    goal: '',
    experienceLevel: '',
    workoutDaysPerWeek: 3,
    equipmentAccess: 'full_gym'
  });
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errors, setErrors] = useState({});
  const navigate = useNavigate();

  const totalSteps = 5;

  const handleInputChange = (field, value) => {
    setFormData(prev => ({
      ...prev,
      [field]: value
    }));

    // Clear error when user starts typing
    if (errors[field]) {
      setErrors(prev => ({
        ...prev,
        [field]: ''
      }));
    }
  };

  const validateStep = (step) => {
    const newErrors = {};

    switch (step) {
      case 2:
        if (!formData.age || formData.age < 13 || formData.age > 100) {
          newErrors.age = 'Please enter a valid age (13-100)';
        }
        if (!formData.gender) {
          newErrors.gender = 'Please select your gender';
        }
        if (!formData.height || formData.height < 100 || formData.height > 250) {
          newErrors.height = 'Please enter a valid height (100-250 cm)';
        }
        if (!formData.weight || formData.weight < 30 || formData.weight > 300) {
          newErrors.weight = 'Please enter a valid weight (30-300 kg)';
        }
        break;
      case 3:
        if (!formData.goal) {
          newErrors.goal = 'Please select your fitness goal';
        }
        break;
      case 4:
        if (!formData.experienceLevel) {
          newErrors.experienceLevel = 'Please select your experience level';
        }
        break;
      case 5:
        if (!formData.workoutDaysPerWeek || formData.workoutDaysPerWeek < 1 || formData.workoutDaysPerWeek > 7) {
          newErrors.workoutDaysPerWeek = 'Please select 1-7 days per week';
        }
        if (!formData.equipmentAccess) {
          newErrors.equipmentAccess = 'Please select your equipment access';
        }
        break;
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const nextStep = () => {
    if (validateStep(currentStep)) {
      setCurrentStep(prev => Math.min(prev + 1, totalSteps));
    }
  };

  const prevStep = () => {
    setCurrentStep(prev => Math.max(prev - 1, 1));
  };

  const handleSubmit = async () => {
    if (!validateStep(currentStep)) return;

    setIsSubmitting(true);

    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`${BASE_URL}/api/user/onboarding`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(formData)
      });

      if (!response.ok) {
        throw new Error('Failed to complete onboarding');
      }

      // Show success animation
      setTimeout(() => {
        navigate('/dashboard');
      }, 2000);

    } catch (error) {
      console.error('Onboarding error:', error);
      setErrors({ submit: 'Failed to complete onboarding. Please try again.' });
    } finally {
      setIsSubmitting(false);
    }
  };

  const slideVariants = {
    enter: (direction) => ({ x: direction > 0 ? 80 : -80, opacity: 0 }),
    center: { x: 0, opacity: 1 },
    exit: (direction) => ({ x: direction < 0 ? 80 : -80, opacity: 0 }),
  };

  const inputClass = (field) =>
    `w-full min-h-11 bg-surface-2 border rounded-xl px-4 py-3 text-sm text-white placeholder-slate-500 focus:outline-none focus:ring-1 transition-colors ${
      errors[field]
        ? 'border-error focus:border-error focus:ring-error/30'
        : 'border-border-subtle focus:border-primary focus:ring-primary/30'
    }`;

  const renderStep = () => {
    switch (currentStep) {
      case 1:
        return (
          <div className="text-center py-4">
            <motion.div
              className="text-6xl mb-6"
              animate={{ scale: [1, 1.1, 1] }}
              transition={{ duration: 2, repeat: Infinity, ease: 'easeInOut' }}
            >
              &#128170;
            </motion.div>
            <h1 className="text-display-sm mb-3">Welcome to Exerly Fitness!</h1>
            <p className="text-slate-400 text-lg mb-8">Let's personalize your experience in 2 minutes</p>
            <div className="flex flex-col gap-3 max-w-xs mx-auto">
              {[
                { icon: '\uD83C\uDFAF', text: 'Personalized workout plans' },
                { icon: '\uD83D\uDCCA', text: 'Track your progress' },
                { icon: '\uD83E\uDD16', text: 'AI-powered coaching' },
              ].map((f) => (
                <GlassCard key={f.text} hover={false} className="flex items-center gap-3 py-3 px-4">
                  <span className="text-xl">{f.icon}</span>
                  <span className="text-sm text-slate-300">{f.text}</span>
                </GlassCard>
              ))}
            </div>
          </div>
        );

      case 2:
        return (
          <div>
            <h2 className="text-display-sm mb-2 text-center">Basic Information</h2>
            <p className="text-slate-400 text-center mb-6">Help us understand your starting point</p>

            <div className="space-y-4 max-w-md mx-auto">
              {/* Age */}
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-1.5">Age</label>
                <input
                  type="number"
                  value={formData.age}
                  onChange={(e) => handleInputChange('age', parseInt(e.target.value))}
                  placeholder="25"
                  min="13"
                  max="100"
                  className={inputClass('age')}
                />
                {errors.age && <p className="text-xs text-error mt-1">{errors.age}</p>}
              </div>

              {/* Gender */}
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-1.5">Gender</label>
                <div className="grid grid-cols-2 gap-2">
                  {['Male', 'Female', 'Other', 'Prefer not to say'].map(option => (
                    <button
                      key={option}
                      type="button"
                      onClick={() => handleInputChange('gender', option.toLowerCase())}
                      className={`min-h-11 rounded-xl px-3 py-2.5 text-sm font-medium transition-all border cursor-pointer ${
                        formData.gender === option.toLowerCase()
                          ? 'bg-primary/15 border-primary text-primary-bright'
                          : 'bg-surface-2 border-border-subtle text-slate-400 hover:border-slate-500'
                      }`}
                    >
                      {option}
                    </button>
                  ))}
                </div>
                {errors.gender && <p className="text-xs text-error mt-1">{errors.gender}</p>}
              </div>

              {/* Height & Weight */}
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-1.5">Height (cm)</label>
                  <input
                    type="number"
                    value={formData.height}
                    onChange={(e) => handleInputChange('height', parseInt(e.target.value))}
                    placeholder="175"
                    min="100"
                    max="250"
                    className={inputClass('height')}
                  />
                  {errors.height && <p className="text-xs text-error mt-1">{errors.height}</p>}
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-1.5">Weight (kg)</label>
                  <input
                    type="number"
                    value={formData.weight}
                    onChange={(e) => handleInputChange('weight', parseInt(e.target.value))}
                    placeholder="70"
                    min="30"
                    max="300"
                    className={inputClass('weight')}
                  />
                  {errors.weight && <p className="text-xs text-error mt-1">{errors.weight}</p>}
                </div>
              </div>
            </div>
          </div>
        );

      case 3:
        return (
          <div>
            <h2 className="text-display-sm mb-2 text-center">What's your main fitness goal?</h2>
            <p className="text-slate-400 text-center mb-6">Choose the goal that motivates you most</p>

            <div className="grid sm:grid-cols-2 gap-3 max-w-lg mx-auto">
              {[
                { id: 'lose_weight', icon: '\uD83D\uDD25', title: 'Lose Weight', desc: 'Burn fat and get lean' },
                { id: 'build_muscle', icon: '\uD83D\uDCAA', title: 'Build Muscle', desc: 'Gain strength and size' },
                { id: 'improve_endurance', icon: '\uD83C\uDFC3', title: 'Improve Endurance', desc: 'Build cardiovascular fitness' },
                { id: 'stay_healthy', icon: '\u2696\uFE0F', title: 'Stay Healthy', desc: 'Maintain current fitness' }
              ].map(goal => (
                <div
                  key={goal.id}
                  role="button"
                  tabIndex={0}
                  onClick={() => handleInputChange('goal', goal.id)}
                  onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); handleInputChange('goal', goal.id); } }}
                >
                  <GlassCard
                    hover
                    className={`cursor-pointer text-center py-5 transition-all border h-full ${
                      formData.goal === goal.id
                        ? '!border-primary shadow-glow-primary'
                        : 'border-transparent'
                    }`}
                  >
                    <span className="text-3xl mb-2 block">{goal.icon}</span>
                    <h3 className="font-semibold text-white text-sm mb-0.5">{goal.title}</h3>
                    <p className="text-xs text-slate-400">{goal.desc}</p>
                  </GlassCard>
                </div>
              ))}
            </div>
            {errors.goal && <p className="text-xs text-error mt-3 text-center">{errors.goal}</p>}
          </div>
        );

      case 4:
        return (
          <div>
            <h2 className="text-display-sm mb-2 text-center">What's your fitness experience?</h2>
            <p className="text-slate-400 text-center mb-6">This helps us create the right plan for you</p>

            <div className="grid sm:grid-cols-3 gap-3 max-w-xl mx-auto">
              {[
                { id: 'beginner', icon: '\uD83C\uDF31', title: 'Beginner', desc: '0-6 months experience', subtext: 'New to working out' },
                { id: 'intermediate', icon: '\uD83D\uDE80', title: 'Intermediate', desc: '6 months - 2 years', subtext: 'Some experience' },
                { id: 'advanced', icon: '\uD83D\uDC8E', title: 'Advanced', desc: '2+ years experience', subtext: 'Very experienced' }
              ].map(level => (
                <div
                  key={level.id}
                  role="button"
                  tabIndex={0}
                  onClick={() => handleInputChange('experienceLevel', level.id)}
                  onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); handleInputChange('experienceLevel', level.id); } }}
                >
                  <GlassCard
                    hover
                    className={`cursor-pointer text-center py-5 transition-all border h-full ${
                      formData.experienceLevel === level.id
                        ? '!border-primary shadow-glow-primary'
                        : 'border-transparent'
                    }`}
                  >
                    <span className="text-3xl mb-2 block">{level.icon}</span>
                    <h3 className="font-semibold text-white text-sm mb-0.5">{level.title}</h3>
                    <p className="text-xs text-slate-400 mb-1">{level.desc}</p>
                    <span className="text-xs text-slate-500">{level.subtext}</span>
                  </GlassCard>
                </div>
              ))}
            </div>
            {errors.experienceLevel && <p className="text-xs text-error mt-3 text-center">{errors.experienceLevel}</p>}
          </div>
        );

      case 5:
        return (
          <div>
            <h2 className="text-display-sm mb-2 text-center">Your workout schedule</h2>
            <p className="text-slate-400 text-center mb-6">How often can you commit to working out?</p>

            <div className="space-y-8 max-w-lg mx-auto">
              {/* Days per week slider */}
              <div>
                <div className="flex items-center justify-between mb-3">
                  <label className="text-sm font-medium text-slate-300">Days per week</label>
                  <span className="text-lg font-bold text-primary-bright">{formData.workoutDaysPerWeek}</span>
                </div>
                <input
                  type="range"
                  min="1"
                  max="7"
                  value={formData.workoutDaysPerWeek}
                  onChange={(e) => handleInputChange('workoutDaysPerWeek', parseInt(e.target.value))}
                  className="w-full h-2 rounded-full appearance-none cursor-pointer bg-surface-3 accent-violet-500"
                  style={{ accentColor: '#8b5cf6' }}
                />
                <div className="flex justify-between mt-1.5">
                  <span className="text-xs text-slate-500">1 day</span>
                  <span className="text-xs text-slate-500">7 days</span>
                </div>
                {errors.workoutDaysPerWeek && <p className="text-xs text-error mt-1">{errors.workoutDaysPerWeek}</p>}
              </div>

              {/* Equipment access */}
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-3">Equipment access</label>
                <div className="grid sm:grid-cols-3 gap-3">
                  {[
                    { id: 'full_gym', icon: '\u2705', title: 'Full Gym Access', desc: 'I have access to a complete gym' },
                    { id: 'home_gym', icon: '\uD83C\uDFE0', title: 'Home Gym', desc: 'Limited equipment at home' },
                    { id: 'no_equipment', icon: '\uD83D\uDEAB', title: 'No Equipment', desc: 'Bodyweight exercises only' }
                  ].map(equipment => (
                    <div
                      key={equipment.id}
                      role="button"
                      tabIndex={0}
                      onClick={() => handleInputChange('equipmentAccess', equipment.id)}
                      onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); handleInputChange('equipmentAccess', equipment.id); } }}
                    >
                      <GlassCard
                        hover
                        className={`cursor-pointer text-center py-4 transition-all border h-full ${
                          formData.equipmentAccess === equipment.id
                            ? '!border-primary shadow-glow-primary'
                            : 'border-transparent'
                        }`}
                      >
                        <span className="text-2xl mb-1.5 block">{equipment.icon}</span>
                        <h4 className="font-semibold text-white text-xs mb-0.5">{equipment.title}</h4>
                        <p className="text-xs text-slate-400">{equipment.desc}</p>
                      </GlassCard>
                    </div>
                  ))}
                </div>
                {errors.equipmentAccess && <p className="text-xs text-error mt-2">{errors.equipmentAccess}</p>}
              </div>
            </div>
          </div>
        );

      default:
        return null;
    }
  };

  // Success / submitting screen
  if (isSubmitting) {
    return (
      <PageTransition className="min-h-screen bg-deep text-white flex items-center justify-center px-4">
        <div className="max-w-md w-full text-center">
          <GlassCard elevated className="rounded-2xl py-10 px-6">
            {/* Animated checkmark */}
            <motion.div
              initial={{ scale: 0 }}
              animate={{ scale: 1 }}
              transition={{ type: 'spring', stiffness: 200, damping: 14, delay: 0.1 }}
              className="w-20 h-20 rounded-full bg-success/20 border-2 border-success flex items-center justify-center mx-auto mb-4"
            >
              <motion.span
                initial={{ opacity: 0, scale: 0 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ delay: 0.3, duration: 0.3 }}
                className="text-3xl text-success"
              >
                &#10003;
              </motion.span>
            </motion.div>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.4 }}
              className="text-3xl mb-4"
            >
              &#127881;
            </motion.div>
            <h1 className="text-display-sm mb-2">Setup Complete!</h1>
            <p className="text-slate-400 mb-6">Your profile is ready!</p>

            <div className="bg-surface-2 rounded-xl p-4 mb-6 text-left">
              <h3 className="text-sm font-semibold text-white mb-3">Your Profile Summary:</h3>
              <div className="space-y-2">
                {[
                  { label: 'Goal', value: formData.goal.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase()) },
                  { label: 'Experience', value: formData.experienceLevel.charAt(0).toUpperCase() + formData.experienceLevel.slice(1) },
                  { label: 'Workouts', value: `${formData.workoutDaysPerWeek} days/week` },
                ].map((item) => (
                  <div key={item.label} className="flex justify-between py-1.5 border-b border-border-subtle last:border-0">
                    <span className="text-sm text-slate-400">{item.label}</span>
                    <span className="text-sm font-medium text-white">{item.value}</span>
                  </div>
                ))}
              </div>
            </div>

            <p className="text-xs text-slate-500">
              &#128172; Want personalized advice? Try our AI Coach (5 questions/hour, max 20/day)
            </p>
          </GlassCard>
        </div>
      </PageTransition>
    );
  }

  const progressPercent = (currentStep / totalSteps) * 100;

  return (
    <PageTransition className="min-h-screen bg-deep text-white flex flex-col">
      {/* Background orbs */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none -z-0">
        <motion.div
          className="absolute top-[-15%] right-[-10%] w-[450px] h-[450px] rounded-full opacity-15"
          style={{ background: 'radial-gradient(circle, #8b5cf6 0%, transparent 70%)' }}
          animate={{ x: [0, 20, 0], y: [0, -20, 0] }}
          transition={{ duration: 10, repeat: Infinity, ease: 'easeInOut' }}
        />
        <motion.div
          className="absolute bottom-[-10%] left-[-5%] w-[350px] h-[350px] rounded-full opacity-10"
          style={{ background: 'radial-gradient(circle, #ec4899 0%, transparent 70%)' }}
          animate={{ x: [0, -15, 0], y: [0, 15, 0] }}
          transition={{ duration: 12, repeat: Infinity, ease: 'easeInOut' }}
        />
      </div>

      {/* Header with progress */}
      <div className="relative z-10 px-4 sm:px-6 lg:px-8 pt-6 pb-4 max-w-2xl mx-auto w-full">
        {/* Progress bar */}
        <div className="h-1.5 bg-surface-3 rounded-full overflow-hidden mb-4">
          <motion.div
            className="h-full bg-gradient-primary rounded-full"
            initial={{ width: 0 }}
            animate={{ width: `${progressPercent}%` }}
            transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
          />
        </div>

        {/* Step indicators */}
        <div className="flex items-center justify-between mb-2">
          {Array.from({ length: totalSteps }, (_, i) => i + 1).map((step) => (
            <React.Fragment key={step}>
              {step > 1 && (
                <div className={`flex-1 h-px mx-1 transition-colors duration-300 ${
                  step <= currentStep ? 'bg-primary/50' : 'bg-surface-3'
                }`} />
              )}
              <div
                className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-semibold transition-all duration-300 shrink-0 ${
                  step < currentStep
                    ? 'bg-primary text-white'
                    : step === currentStep
                      ? 'bg-gradient-primary text-white shadow-glow-sm'
                      : 'bg-surface-3 text-slate-500'
                }`}
              >
                {step < currentStep ? (
                  <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                  </svg>
                ) : (
                  step
                )}
              </div>
            </React.Fragment>
          ))}
        </div>

        <p className="text-xs text-slate-500 text-center">{currentStep} of {totalSteps}</p>
      </div>

      {/* Step content */}
      <div className="relative z-10 flex-1 px-4 sm:px-6 lg:px-8 max-w-2xl mx-auto w-full py-4 overflow-y-auto">
        <AnimatePresence mode="wait" custom={1}>
          <motion.div
            key={currentStep}
            custom={1}
            variants={slideVariants}
            initial="enter"
            animate="center"
            exit="exit"
            transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
          >
            {renderStep()}
          </motion.div>
        </AnimatePresence>
      </div>

      {/* Footer actions */}
      <div className="relative z-10 px-4 sm:px-6 lg:px-8 py-5 max-w-2xl mx-auto w-full">
        {errors.submit && (
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            className="mb-4 rounded-xl bg-error/10 border border-error/20 px-4 py-3 text-sm text-error text-center"
          >
            {errors.submit}
          </motion.div>
        )}

        <div className="flex gap-3">
          {currentStep > 1 && (
            <ActionButton variant="secondary" onClick={prevStep} className="min-h-12 px-6">
              Back
            </ActionButton>
          )}

          {currentStep < totalSteps ? (
            <ActionButton variant="primary" onClick={nextStep} className="min-h-12 px-8 flex-1">
              Next
            </ActionButton>
          ) : (
            <ActionButton
              variant="primary"
              onClick={handleSubmit}
              loading={isSubmitting}
              className="min-h-12 px-8 flex-1"
            >
              Complete Setup
            </ActionButton>
          )}
        </div>
      </div>
    </PageTransition>
  );
};

export default Onboarding;
