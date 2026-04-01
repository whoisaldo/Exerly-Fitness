import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import exerly_logo from './Assets/ExerlyLogo.jpg';
import { GlassCard, ActionButton } from './ui';

export default function LandingPage() {
  const navigate = useNavigate();
  const [currentFeature, setCurrentFeature] = useState(0);
  const [stats, setStats] = useState({
    users: 0,
    activities: 0,
    meals: 0,
    hours: 0
  });

  const features = [
    {
      icon: '\uD83C\uDFAF',
      title: 'Smart Activity Tracking',
      description: 'Track workouts, runs, and daily activities with intelligent categorization and intensity monitoring.',
      image: '\uD83C\uDFC3\u200D\u2642\uFE0F'
    },
    {
      icon: '\uD83C\uDF4E',
      title: 'Nutrition Management',
      description: 'Log meals with detailed macro tracking including protein, carbs, fat, and sugar monitoring.',
      image: '\uD83D\uDCCA'
    },
    {
      icon: '\uD83D\uDE34',
      title: 'Sleep Analytics',
      description: 'Monitor sleep patterns with bedtime and wake time tracking for optimal recovery.',
      image: '\uD83C\uDF19'
    },
    {
      icon: '\uD83D\uDCC8',
      title: 'Progress Dashboard',
      description: 'Comprehensive analytics with goal tracking, progress charts, and personalized insights.',
      image: '\uD83D\uDCCA'
    }
  ];

  const techStack = [
    { name: 'React.js', icon: '\u269B\uFE0F', description: 'Modern UI Framework' },
    { name: 'Node.js', icon: '\uD83D\uDFE2', description: 'Backend Runtime' },
    { name: 'MongoDB', icon: '\uD83C\uDF43', description: 'NoSQL Database' },
    { name: 'Express.js', icon: '\uD83D\uDE80', description: 'Web Framework' },
    { name: 'JWT Auth', icon: '\uD83D\uDD10', description: 'Secure Authentication' },
    { name: 'RESTful API', icon: '\uD83C\uDF10', description: 'Scalable Architecture' }
  ];

  const testimonials = [
    {
      text: "Exerly has transformed how I track my fitness journey. The interface is intuitive and the analytics are incredibly detailed.",
      author: "Sarah Chen",
      role: "Fitness Enthusiast"
    },
    {
      text: "The macro tracking feature is exactly what I needed for my nutrition goals. Clean, simple, and effective.",
      author: "Mike Rodriguez",
      role: "Health Coach"
    },
    {
      text: "As a developer, I'm impressed by the clean codebase and modern tech stack. Great work!",
      author: "Alex Thompson",
      role: "Full-Stack Developer"
    }
  ];

  // Animate stats on load
  useEffect(() => {
    const animateStats = () => {
      const targets = { users: 1247, activities: 15680, meals: 8934, hours: 2456 };
      const duration = 2000;
      const steps = 60;
      const stepDuration = duration / steps;

      let step = 0;
      const timer = setInterval(() => {
        step++;
        const progress = step / steps;
        const easeOut = 1 - Math.pow(1 - progress, 3);

        setStats({
          users: Math.floor(targets.users * easeOut),
          activities: Math.floor(targets.activities * easeOut),
          meals: Math.floor(targets.meals * easeOut),
          hours: Math.floor(targets.hours * easeOut)
        });

        if (step >= steps) {
          clearInterval(timer);
          setStats(targets);
        }
      }, stepDuration);
    };

    const timer = setTimeout(animateStats, 1000);
    return () => clearTimeout(timer);
  }, []);

  // Auto-rotate features
  useEffect(() => {
    const interval = setInterval(() => {
      setCurrentFeature((prev) => (prev + 1) % features.length);
    }, 4000);
    return () => clearInterval(interval);
  }, []);

  const statItems = [
    { label: 'Active Users', value: stats.users },
    { label: 'Activities Tracked', value: stats.activities },
    { label: 'Meals Logged', value: stats.meals },
    { label: 'Sleep Hours Monitored', value: stats.hours },
  ];

  const chartHeights = [60, 80, 45, 90, 70, 85, 95];

  return (
    <div className="min-h-screen bg-deep text-white overflow-x-hidden">
      {/* Animated background orbs */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none -z-0">
        <motion.div
          className="absolute top-[-20%] left-[-10%] w-[600px] h-[600px] rounded-full opacity-20"
          style={{ background: 'radial-gradient(circle, #8b5cf6 0%, transparent 70%)' }}
          animate={{ x: [0, 40, 0], y: [0, 30, 0] }}
          transition={{ duration: 8, repeat: Infinity, ease: 'easeInOut' }}
        />
        <motion.div
          className="absolute bottom-[-10%] right-[-10%] w-[500px] h-[500px] rounded-full opacity-15"
          style={{ background: 'radial-gradient(circle, #ec4899 0%, transparent 70%)' }}
          animate={{ x: [0, -30, 0], y: [0, -40, 0] }}
          transition={{ duration: 10, repeat: Infinity, ease: 'easeInOut' }}
        />
        <motion.div
          className="absolute top-[40%] left-[50%] w-[400px] h-[400px] rounded-full opacity-10"
          style={{ background: 'radial-gradient(circle, #8b5cf6 0%, transparent 70%)' }}
          animate={{ x: [0, -20, 0], y: [0, 20, 0] }}
          transition={{ duration: 12, repeat: Infinity, ease: 'easeInOut' }}
        />
      </div>

      {/* Navigation */}
      <nav className="relative z-10 border-b border-border-subtle">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <img src={exerly_logo} alt="Exerly" className="w-9 h-9 rounded-lg object-cover" />
            <span className="text-lg font-bold tracking-tight text-white">Exerly</span>
          </div>
          <div className="flex items-center gap-3">
            <ActionButton variant="ghost" onClick={() => navigate('/login')}>
              Try Demo
            </ActionButton>
            <ActionButton variant="primary" onClick={() => navigate('/login')}>
              Sign In
            </ActionButton>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="relative z-10 pt-20 pb-24 lg:pt-28 lg:pb-32">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid lg:grid-cols-2 gap-12 lg:gap-16 items-center">
            {/* Hero text */}
            <motion.div
              initial={{ opacity: 0, y: 24 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
            >
              <div className="inline-flex items-center gap-2 glass rounded-full px-4 py-1.5 text-xs font-medium text-primary-bright mb-6">
                <span>🚀</span>
                Modern Fitness App
              </div>
              <h1 className="text-display-xl mb-6">
                Transform Your{' '}
                <span className="bg-gradient-primary bg-clip-text text-transparent">
                  Fitness Journey
                </span>{' '}
                with Smart Analytics
              </h1>
              <p className="text-lg text-slate-400 leading-relaxed mb-8 max-w-xl">
                Track activities, monitor nutrition, analyze sleep patterns, and achieve your goals with
                Exerly's comprehensive fitness management platform built with cutting-edge technology.
              </p>
              <div className="flex flex-wrap gap-4">
                <ActionButton variant="primary" onClick={() => navigate('/login')} className="min-h-11 px-7 text-base">
                  Get Started
                  <span className="ml-1">&rarr;</span>
                </ActionButton>
                <ActionButton variant="secondary" onClick={() => navigate('/credits')} className="min-h-11 px-7 text-base">
                  See Demo
                </ActionButton>
              </div>
            </motion.div>

            {/* Dashboard preview */}
            <motion.div
              initial={{ opacity: 0, y: 32, scale: 0.96 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              transition={{ duration: 0.7, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
              className="hidden lg:block"
            >
              <GlassCard elevated className="rounded-2xl overflow-hidden">
                {/* Window chrome */}
                <div className="flex items-center gap-2 pb-4 border-b border-border-subtle mb-4">
                  <span className="w-3 h-3 rounded-full bg-red-500/60" />
                  <span className="w-3 h-3 rounded-full bg-yellow-500/60" />
                  <span className="w-3 h-3 rounded-full bg-green-500/60" />
                  <span className="ml-3 text-xs text-slate-500 font-medium">Exerly Dashboard</span>
                </div>
                {/* Mock stats row */}
                <div className="grid grid-cols-3 gap-3 mb-5">
                  {[
                    { val: '2,847', lbl: 'Calories Burned' },
                    { val: '8.5h', lbl: 'Sleep Quality' },
                    { val: '156g', lbl: 'Protein Intake' },
                  ].map((s, i) => (
                    <div key={i} className="bg-surface-2 rounded-xl p-3 text-center">
                      <div className="text-stat text-primary-bright">{s.val}</div>
                      <div className="text-label text-slate-500 mt-0.5">{s.lbl}</div>
                    </div>
                  ))}
                </div>
                {/* Mock bar chart */}
                <div className="flex items-end justify-between gap-2 h-28 px-2">
                  {chartHeights.map((h, i) => (
                    <motion.div
                      key={i}
                      className="flex-1 rounded-t-md bg-gradient-primary"
                      initial={{ height: 0 }}
                      animate={{ height: `${h}%` }}
                      transition={{ duration: 0.6, delay: 0.4 + i * 0.08, ease: [0.16, 1, 0.3, 1] }}
                    />
                  ))}
                </div>
              </GlassCard>
            </motion.div>
          </div>
        </div>
      </section>

      {/* Stats Ticker */}
      <section className="relative z-10 py-10 border-y border-border-subtle bg-surface-1/60 backdrop-blur-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-6 text-center">
            {statItems.map((s, i) => (
              <motion.div
                key={s.label}
                initial={{ opacity: 0, y: 16 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: i * 0.1, duration: 0.5 }}
              >
                <div className="text-stat text-2xl md:text-3xl font-bold bg-gradient-primary bg-clip-text text-transparent">
                  {s.value.toLocaleString()}
                </div>
                <div className="text-label text-slate-500 mt-1">{s.label}</div>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="relative z-10 py-20 lg:py-28">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <motion.div
            className="text-center max-w-2xl mx-auto mb-14"
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
          >
            <h2 className="text-display-sm mb-3">Powerful Features for Modern Fitness</h2>
            <p className="text-slate-400 text-lg">
              Everything you need to track, analyze, and optimize your health and fitness journey.
            </p>
          </motion.div>

          <div className="grid lg:grid-cols-2 gap-10 items-center">
            {/* Feature text side */}
            <div>
              <AnimatePresence mode="wait">
                <motion.div
                  key={currentFeature}
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: 20 }}
                  transition={{ duration: 0.35 }}
                >
                  <span className="text-4xl mb-4 block">{features[currentFeature].icon}</span>
                  <h3 className="text-display-sm mb-3">{features[currentFeature].title}</h3>
                  <p className="text-slate-400 text-lg leading-relaxed">
                    {features[currentFeature].description}
                  </p>
                </motion.div>
              </AnimatePresence>
              {/* Indicators */}
              <div className="flex gap-2 mt-8">
                {features.map((_, index) => (
                  <button
                    key={index}
                    onClick={() => setCurrentFeature(index)}
                    className={`h-2 rounded-full transition-all duration-300 min-h-0 ${
                      index === currentFeature
                        ? 'w-8 bg-gradient-primary'
                        : 'w-2 bg-slate-600 hover:bg-slate-500'
                    }`}
                    aria-label={`Feature ${index + 1}`}
                  />
                ))}
              </div>
            </div>

            {/* Feature mockup side */}
            <AnimatePresence mode="wait">
              <motion.div
                key={currentFeature}
                initial={{ opacity: 0, scale: 0.96 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.96 }}
                transition={{ duration: 0.35 }}
              >
                <GlassCard elevated className="rounded-2xl">
                  <div className="flex items-center justify-between mb-5">
                    <span className="text-sm font-medium text-white">{features[currentFeature].title}</span>
                    <span className="text-2xl">{features[currentFeature].image}</span>
                  </div>
                  <div className="space-y-3">
                    {[
                      { lbl: "Today's Progress", val: '85%' },
                      { lbl: 'Weekly Goal', val: '6/7 days' },
                      { lbl: 'Trend', val: '+12%', accent: true },
                    ].map((row) => (
                      <div key={row.lbl} className="flex items-center justify-between py-2.5 border-b border-border-subtle last:border-0">
                        <span className="text-sm text-slate-400">{row.lbl}</span>
                        <span className={`text-sm font-semibold ${row.accent ? 'text-success' : 'text-white'}`}>
                          {row.accent && '\u2197 '}{row.val}
                        </span>
                      </div>
                    ))}
                  </div>
                </GlassCard>
              </motion.div>
            </AnimatePresence>
          </div>
        </div>
      </section>

      {/* Features Bento Grid */}
      <section className="relative z-10 pb-20 lg:pb-28">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-5">
            {techStack.map((tech, index) => (
              <motion.div
                key={index}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: index * 0.08, duration: 0.5 }}
              >
                <GlassCard className="h-full">
                  <span className="text-3xl mb-3 block">{tech.icon}</span>
                  <h4 className="font-semibold text-white mb-1">{tech.name}</h4>
                  <p className="text-sm text-slate-400">{tech.description}</p>
                </GlassCard>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* Testimonials */}
      <section className="relative z-10 py-20 lg:py-28 bg-surface-1/40">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <motion.div
            className="text-center max-w-2xl mx-auto mb-14"
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
          >
            <h2 className="text-display-sm mb-3">What Users Say</h2>
            <p className="text-slate-400 text-lg">
              Real feedback from fitness enthusiasts and health professionals.
            </p>
          </motion.div>
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-5">
            {testimonials.map((t, index) => (
              <motion.div
                key={index}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: index * 0.1, duration: 0.5 }}
              >
                <GlassCard className="h-full flex flex-col">
                  <p className="text-slate-300 leading-relaxed flex-1 mb-5">
                    &ldquo;{t.text}&rdquo;
                  </p>
                  <div className="border-t border-border-subtle pt-4">
                    <div className="font-semibold text-white text-sm">{t.author}</div>
                    <div className="text-xs text-slate-500">{t.role}</div>
                  </div>
                </GlassCard>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="relative z-10 py-20 lg:py-28">
        <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <motion.div
            initial={{ opacity: 0, y: 24 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
          >
            <h2 className="text-display-sm mb-4">Ready to Transform Your Fitness Journey?</h2>
            <p className="text-lg text-slate-400 mb-8 max-w-xl mx-auto">
              Join thousands of users who are already achieving their health goals with Exerly.
            </p>
            <div className="flex flex-wrap justify-center gap-4">
              <ActionButton variant="primary" onClick={() => navigate('/login')} className="min-h-12 px-8 text-base">
                Get Started Free
                <span className="ml-1">🚀</span>
              </ActionButton>
              <ActionButton variant="secondary" onClick={() => navigate('/credits')} className="min-h-12 px-8 text-base">
                Learn More
              </ActionButton>
            </div>
          </motion.div>
        </div>
      </section>

      {/* Footer */}
      <footer className="relative z-10 bg-surface-1 border-t border-border-subtle">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
          <div className="grid md:grid-cols-3 gap-10">
            {/* Brand */}
            <div>
              <div className="flex items-center gap-3 mb-3">
                <img src={exerly_logo} alt="Exerly" className="w-8 h-8 rounded-lg object-cover" />
                <span className="font-bold text-white">Exerly</span>
              </div>
              <p className="text-sm text-slate-500 leading-relaxed">
                Modern fitness tracking platform built with React, Node.js, and MongoDB.
              </p>
            </div>
            {/* Product links */}
            <div>
              <h4 className="text-label text-slate-400 font-semibold uppercase tracking-wider mb-3">Product</h4>
              <div className="flex flex-col gap-2">
                <button onClick={() => navigate('/login')} className="text-sm text-slate-500 hover:text-white transition-colors text-left min-h-0 p-0 bg-transparent border-none cursor-pointer">Try Demo</button>
                <button onClick={() => navigate('/login')} className="text-sm text-slate-500 hover:text-white transition-colors text-left min-h-0 p-0 bg-transparent border-none cursor-pointer">Login</button>
                <button onClick={() => navigate('/credits')} className="text-sm text-slate-500 hover:text-white transition-colors text-left min-h-0 p-0 bg-transparent border-none cursor-pointer">About</button>
              </div>
            </div>
            {/* Resources links */}
            <div>
              <h4 className="text-label text-slate-400 font-semibold uppercase tracking-wider mb-3">Resources</h4>
              <div className="flex flex-col gap-2">
                <a href="https://github.com/whoisaldo/Exerly-Fitness" target="_blank" rel="noopener noreferrer" className="text-sm text-slate-500 hover:text-white transition-colors">GitHub</a>
                <a href="https://www.linkedin.com/in/ali-younes-41a2b4296/" target="_blank" rel="noopener noreferrer" className="text-sm text-slate-500 hover:text-white transition-colors">LinkedIn</a>
                <button onClick={() => navigate('/status-check')} className="text-sm text-slate-500 hover:text-white transition-colors text-left min-h-0 p-0 bg-transparent border-none cursor-pointer">Status</button>
              </div>
            </div>
          </div>
          <div className="border-t border-border-subtle mt-10 pt-6 text-center">
            <p className="text-xs text-slate-600">
              &copy; 2025 Exerly. Built with &#10084;&#65039; by Ali Younes.
            </p>
          </div>
        </div>
      </footer>
    </div>
  );
}
