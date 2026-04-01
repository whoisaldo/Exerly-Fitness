import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import API_CONFIG from '../../config';
import {
  GlassCard,
  StatCard,
  PageHeader,
  ActionButton,
  Badge,
  EmptyState,
  LoadingSkeleton,
  PageTransition,
} from '../ui';

const BASE_URL = API_CONFIG.BASE_URL;

export default function Workouts() {
  const navigate = useNavigate();
  const [workouts, setWorkouts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    type: 'strength',
    duration: '',
    difficulty: 'medium',
    description: '',
    exercises: []
  });

  const workoutTypes = [
    { value: 'strength', label: 'Strength Training', icon: '💪' },
    { value: 'cardio', label: 'Cardio', icon: '❤️' },
    { value: 'flexibility', label: 'Flexibility', icon: '🧘' },
    { value: 'hiit', label: 'HIIT', icon: '⚡' },
    { value: 'yoga', label: 'Yoga', icon: '🧘‍♀️' },
    { value: 'sports', label: 'Sports', icon: '⚽' }
  ];

  const difficultyLevels = [
    { value: 'beginner', label: 'Beginner', color: '#00b894' },
    { value: 'medium', label: 'Medium', color: '#fdcb6e' },
    { value: 'advanced', label: 'Advanced', color: '#e17055' }
  ];

  const sampleWorkouts = [
    {
      id: 1,
      name: 'Full Body Strength',
      type: 'strength',
      duration: 45,
      difficulty: 'medium',
      description: 'Complete full body workout targeting all major muscle groups',
      exercises: ['Squats', 'Push-ups', 'Rows', 'Lunges', 'Planks'],
      lastUsed: '2024-01-15'
    },
    {
      id: 2,
      name: 'HIIT Cardio Blast',
      type: 'hiit',
      duration: 30,
      difficulty: 'advanced',
      description: 'High-intensity interval training for maximum calorie burn',
      exercises: ['Burpees', 'Mountain Climbers', 'Jump Squats', 'High Knees'],
      lastUsed: '2024-01-14'
    },
    {
      id: 3,
      name: 'Morning Yoga Flow',
      type: 'yoga',
      duration: 20,
      difficulty: 'beginner',
      description: 'Gentle morning yoga sequence to start your day',
      exercises: ['Sun Salutation', 'Warrior Poses', 'Tree Pose', 'Child\'s Pose'],
      lastUsed: '2024-01-13'
    }
  ];

  useEffect(() => {
    // Simulate loading workouts
    setTimeout(() => {
      setWorkouts(sampleWorkouts);
      setLoading(false);
    }, 1000);
  }, []);

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const addExercise = () => {
    const exercise = prompt('Enter exercise name:');
    if (exercise && exercise.trim()) {
      setFormData(prev => ({
        ...prev,
        exercises: [...prev.exercises, exercise.trim()]
      }));
    }
  };

  const removeExercise = (index) => {
    setFormData(prev => ({
      ...prev,
      exercises: prev.exercises.filter((_, i) => i !== index)
    }));
  };

  const handleSubmit = (e) => {
    e.preventDefault();

    if (!formData.name || !formData.duration) {
      alert('Please fill in all required fields');
      return;
    }

    const newWorkout = {
      id: Date.now(),
      ...formData,
      lastUsed: new Date().toISOString().split('T')[0]
    };

    setWorkouts(prev => [newWorkout, ...prev]);
    setFormData({
      name: '',
      type: 'strength',
      duration: '',
      difficulty: 'medium',
      description: '',
      exercises: []
    });
    setShowForm(false);
  };

  const startWorkout = (workout) => {
    // Here you would typically navigate to a workout session page
    alert(`Starting workout: ${workout.name}`);
  };

  const deleteWorkout = (id) => {
    if (window.confirm('Are you sure you want to delete this workout?')) {
      setWorkouts(prev => prev.filter(w => w.id !== id));
    }
  };

  const getWorkoutTypeIcon = (type) => {
    return workoutTypes.find(t => t.value === type)?.icon || '💪';
  };

  const getDifficultyColor = (difficulty) => {
    return difficultyLevels.find(d => d.value === difficulty)?.color || '#fdcb6e';
  };

  const getDifficultyBadgeVariant = (difficulty) => {
    switch (difficulty) {
      case 'beginner': return 'status';
      case 'medium': return 'meal';
      case 'advanced': return 'severity';
      default: return 'meal';
    }
  };

  const avgDuration = workouts.length > 0
    ? Math.round(workouts.reduce((sum, w) => sum + w.duration, 0) / workouts.length)
    : 0;

  const mostUsedType = workouts.length > 0
    ? workoutTypes.find(t => t.value === workouts[0].type)?.label || 'Strength'
    : 'None';

  if (loading) {
    return (
      <PageTransition className="min-h-screen bg-deep px-4 py-6 sm:px-6 lg:px-8">
        <div className="mx-auto max-w-5xl space-y-8">
          <PageHeader title="Workout Library" subtitle="Plan, save, and track your workouts" />
          <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
            <LoadingSkeleton variant="stat" count={3} />
          </div>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
            <LoadingSkeleton variant="card" count={3} />
          </div>
        </div>
      </PageTransition>
    );
  }

  return (
    <PageTransition className="min-h-screen bg-deep px-4 py-6 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-5xl space-y-8">
        {/* Header */}
        <PageHeader
          title="Workout Library"
          subtitle="Plan, save, and track your workouts"
          action={
            <div className="flex items-center gap-3">
              <ActionButton
                variant="ghost"
                onClick={() => navigate('/dashboard')}
                icon={
                  <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
                  </svg>
                }
              >
                Back
              </ActionButton>
              <ActionButton onClick={() => setShowForm(true)} icon={<span>+</span>}>
                New Workout
              </ActionButton>
            </div>
          }
        />

        {/* Stats Row */}
        <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
          <StatCard
            icon={<span className="text-lg">💪</span>}
            label="Total Workouts"
            value={workouts.length}
          />
          <StatCard
            icon={<span className="text-lg">⏱️</span>}
            label="Avg Duration"
            value={`${avgDuration} min`}
          />
          <StatCard
            icon={<span className="text-lg">🎯</span>}
            label="Most Used Type"
            value={mostUsedType}
          />
        </div>

        {/* Modal */}
        <AnimatePresence>
          {showForm && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.2 }}
              className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4"
              onClick={() => setShowForm(false)}
            >
              <motion.div
                initial={{ opacity: 0, scale: 0.95, y: 16 }}
                animate={{ opacity: 1, scale: 1, y: 0 }}
                exit={{ opacity: 0, scale: 0.95, y: 16 }}
                transition={{ duration: 0.25 }}
                onClick={e => e.stopPropagation()}
                className="w-full max-w-2xl max-h-[90vh] overflow-y-auto"
              >
                <GlassCard elevated className="!p-6">
                  {/* Modal Header */}
                  <div className="mb-6 flex items-center justify-between">
                    <h2 className="text-lg font-semibold text-slate-100">Create New Workout</h2>
                    <button
                      onClick={() => setShowForm(false)}
                      className="flex h-8 w-8 items-center justify-center rounded-lg text-slate-400 transition-colors hover:bg-white/5 hover:text-slate-100"
                    >
                      <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  </div>

                  <form onSubmit={handleSubmit} className="space-y-5">
                    <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
                      <div className="space-y-1.5">
                        <label className="text-label text-slate-300">Workout Name *</label>
                        <input
                          type="text"
                          name="name"
                          value={formData.name}
                          onChange={handleInputChange}
                          placeholder="e.g., Full Body Strength"
                          className="h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 placeholder-slate-500 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/40"
                          required
                        />
                      </div>
                      <div className="space-y-1.5">
                        <label className="text-label text-slate-300">Type</label>
                        <select
                          name="type"
                          value={formData.type}
                          onChange={handleInputChange}
                          className="h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/40"
                        >
                          {workoutTypes.map(type => (
                            <option key={type.value} value={type.value}>
                              {type.icon} {type.label}
                            </option>
                          ))}
                        </select>
                      </div>
                    </div>

                    <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
                      <div className="space-y-1.5">
                        <label className="text-label text-slate-300">Duration (minutes) *</label>
                        <input
                          type="number"
                          name="duration"
                          value={formData.duration}
                          onChange={handleInputChange}
                          placeholder="45"
                          className="h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 placeholder-slate-500 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/40"
                          min="5"
                          max="180"
                          required
                        />
                      </div>
                      <div className="space-y-1.5">
                        <label className="text-label text-slate-300">Difficulty</label>
                        <select
                          name="difficulty"
                          value={formData.difficulty}
                          onChange={handleInputChange}
                          className="h-11 w-full rounded-xl border border-border-subtle bg-surface-2 px-4 text-sm text-slate-100 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/40"
                        >
                          {difficultyLevels.map(level => (
                            <option key={level.value} value={level.value}>
                              {level.label}
                            </option>
                          ))}
                        </select>
                      </div>
                    </div>

                    <div className="space-y-1.5">
                      <label className="text-label text-slate-300">Description</label>
                      <textarea
                        name="description"
                        value={formData.description}
                        onChange={handleInputChange}
                        placeholder="Describe your workout..."
                        rows="3"
                        className="w-full rounded-xl border border-border-subtle bg-surface-2 px-4 py-3 text-sm text-slate-100 placeholder-slate-500 outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary/40"
                      />
                    </div>

                    {/* Exercises */}
                    <div className="space-y-2">
                      <label className="text-label text-slate-300">Exercises</label>
                      <div className="flex flex-wrap gap-2">
                        {formData.exercises.map((exercise, index) => (
                          <Badge key={index} variant="intensity" className="gap-1.5 py-1 pl-3 pr-1.5">
                            {exercise}
                            <button
                              type="button"
                              onClick={() => removeExercise(index)}
                              className="flex h-4 w-4 items-center justify-center rounded-full bg-white/10 text-[10px] hover:bg-white/20"
                            >
                              x
                            </button>
                          </Badge>
                        ))}
                        <button
                          type="button"
                          onClick={addExercise}
                          className="inline-flex h-7 items-center gap-1 rounded-full border border-dashed border-border-subtle px-3 text-xs text-slate-400 transition-colors hover:border-primary/40 hover:text-primary-bright"
                        >
                          + Add
                        </button>
                      </div>
                    </div>

                    {/* Actions */}
                    <div className="flex justify-end gap-3 border-t border-border-subtle pt-5">
                      <ActionButton
                        type="button"
                        variant="secondary"
                        onClick={() => setShowForm(false)}
                      >
                        Cancel
                      </ActionButton>
                      <ActionButton type="submit">
                        Create Workout
                      </ActionButton>
                    </div>
                  </form>
                </GlassCard>
              </motion.div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Workouts Grid */}
        <div className="space-y-4">
          <h2 className="text-lg font-semibold text-slate-100">Your Workouts</h2>

          {workouts.length === 0 ? (
            <GlassCard>
              <EmptyState
                icon={<span className="text-2xl">💪</span>}
                title="No workouts yet"
                message="Create your first workout to start building your fitness routine."
                action={{ label: 'Create Workout', onClick: () => setShowForm(true) }}
              />
            </GlassCard>
          ) : (
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
              {workouts.map((workout, i) => (
                <motion.div
                  key={workout.id}
                  initial={{ opacity: 0, y: 12 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: i * 0.06, duration: 0.35 }}
                >
                  <WorkoutCard
                    workout={workout}
                    getWorkoutTypeIcon={getWorkoutTypeIcon}
                    getDifficultyBadgeVariant={getDifficultyBadgeVariant}
                    startWorkout={startWorkout}
                    deleteWorkout={deleteWorkout}
                  />
                </motion.div>
              ))}
            </div>
          )}
        </div>
      </div>
    </PageTransition>
  );
}

/* ---------- Workout card with expandable exercises ---------- */
function WorkoutCard({ workout, getWorkoutTypeIcon, getDifficultyBadgeVariant, startWorkout, deleteWorkout }) {
  const [expanded, setExpanded] = useState(false);

  return (
    <GlassCard className="flex h-full flex-col group">
      {/* Card Header */}
      <div className="flex items-start justify-between">
        <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-xl">
          {getWorkoutTypeIcon(workout.type)}
        </div>
        <div className="flex items-center gap-2">
          <Badge variant={getDifficultyBadgeVariant(workout.difficulty)}>
            {workout.difficulty}
          </Badge>
          <span className="text-xs text-slate-400">{workout.duration} min</span>
        </div>
      </div>

      {/* Content */}
      <div className="mt-4 flex-1">
        <h3 className="font-semibold text-slate-100">{workout.name}</h3>
        {workout.description && (
          <p className="mt-1 text-xs leading-relaxed text-slate-400 line-clamp-2">{workout.description}</p>
        )}

        {/* Exercises - expandable */}
        {workout.exercises.length > 0 && (
          <div className="mt-3">
            <button
              type="button"
              onClick={() => setExpanded(prev => !prev)}
              className="flex items-center gap-1.5 text-xs font-medium text-primary-bright transition-colors hover:text-primary"
            >
              <Badge variant="intensity">{workout.exercises.length} exercises</Badge>
              <svg
                className={`h-3.5 w-3.5 transition-transform ${expanded ? 'rotate-180' : ''}`}
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                strokeWidth={2}
              >
                <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
              </svg>
            </button>

            <AnimatePresence>
              {expanded && (
                <motion.ul
                  initial={{ height: 0, opacity: 0 }}
                  animate={{ height: 'auto', opacity: 1 }}
                  exit={{ height: 0, opacity: 0 }}
                  transition={{ duration: 0.2 }}
                  className="mt-2 space-y-1 overflow-hidden"
                >
                  {workout.exercises.map((exercise, idx) => (
                    <li key={idx} className="flex items-center gap-2 text-xs text-slate-300">
                      <span className="h-1 w-1 rounded-full bg-primary" />
                      {exercise}
                    </li>
                  ))}
                </motion.ul>
              )}
            </AnimatePresence>
          </div>
        )}
      </div>

      {/* Footer */}
      <div className="mt-4 flex items-center justify-between border-t border-border-subtle pt-3">
        <span className="text-[11px] text-slate-500">Last: {workout.lastUsed}</span>
        <div className="flex items-center gap-2">
          <ActionButton
            variant="primary"
            onClick={() => startWorkout(workout)}
            className="!px-3.5 !py-1.5 !text-xs"
          >
            Start
          </ActionButton>
          <button
            onClick={() => deleteWorkout(workout.id)}
            className="h-8 rounded-lg px-2.5 text-xs text-slate-400 opacity-0 transition-all hover:bg-error/10 hover:text-error group-hover:opacity-100"
          >
            <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
          </button>
        </div>
      </div>
    </GlassCard>
  );
}
