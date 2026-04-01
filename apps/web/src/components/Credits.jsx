import React from 'react';
import { Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import exerly_logo from './Assets/ExerlyLogo.jpg';
import { GlassCard, ActionButton, PageTransition } from './ui';

const featureCards = [
  { icon: '\uD83C\uDFAF', title: 'Smart Tracking', desc: 'Intelligent activity and nutrition tracking with personalized insights' },
  { icon: '\uD83D\uDCCA', title: 'Analytics Dashboard', desc: 'Comprehensive data visualization and progress monitoring' },
  { icon: '\u26A1', title: 'Modern Tech', desc: 'Built with React, Node.js, and MongoDB for optimal performance' },
  { icon: '\uD83D\uDD12', title: 'Secure & Private', desc: 'Your data is protected with enterprise-grade security' },
];

const Credits = () => {
  return (
    <PageTransition className="min-h-screen bg-deep text-white">
      {/* Background orbs */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none -z-0">
        <motion.div
          className="absolute top-[-15%] right-[-10%] w-[500px] h-[500px] rounded-full opacity-15"
          style={{ background: 'radial-gradient(circle, #8b5cf6 0%, transparent 70%)' }}
          animate={{ x: [0, 30, 0], y: [0, -20, 0] }}
          transition={{ duration: 10, repeat: Infinity, ease: 'easeInOut' }}
        />
        <motion.div
          className="absolute bottom-[-10%] left-[-5%] w-[400px] h-[400px] rounded-full opacity-10"
          style={{ background: 'radial-gradient(circle, #ec4899 0%, transparent 70%)' }}
          animate={{ x: [0, -20, 0], y: [0, 20, 0] }}
          transition={{ duration: 12, repeat: Infinity, ease: 'easeInOut' }}
        />
      </div>

      <div className="relative z-10 max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Back button */}
        <Link to="/">
          <ActionButton variant="ghost" className="mb-8 min-h-11">
            &larr; Back
          </ActionButton>
        </Link>

        {/* Header / Brand */}
        <motion.div
          className="text-center mb-14"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
        >
          <img
            src={exerly_logo}
            alt="Exerly Logo"
            className="w-20 h-20 rounded-2xl object-cover mx-auto mb-5 shadow-glow-primary"
          />
          <h1 className="text-display mb-2">About Exerly</h1>
          <p className="text-lg text-slate-400">Redefining fitness tracking with modern technology</p>
        </motion.div>

        {/* Creator section */}
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.15, duration: 0.5 }}
          className="mb-14"
        >
          <GlassCard elevated className="text-center py-8 rounded-2xl">
            <p className="text-sm text-slate-400 uppercase tracking-wider mb-3">Crafted with &#128156; by</p>
            <h2 className="text-2xl font-bold bg-gradient-primary bg-clip-text text-transparent mb-1">
              Ali Younes
            </h2>
            <p className="text-slate-400">Full-Stack Developer &amp; Fitness Enthusiast</p>
          </GlassCard>
        </motion.div>

        {/* Feature highlights */}
        <div className="mb-14">
          <h3 className="text-display-sm text-center mb-8">What makes Exerly special?</h3>
          <div className="grid sm:grid-cols-2 gap-5">
            {featureCards.map((f, i) => (
              <motion.div
                key={f.title}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.2 + i * 0.08, duration: 0.5 }}
              >
                <GlassCard className="h-full">
                  <span className="text-3xl mb-3 block">{f.icon}</span>
                  <h4 className="font-semibold text-white mb-1">{f.title}</h4>
                  <p className="text-sm text-slate-400 leading-relaxed">{f.desc}</p>
                </GlassCard>
              </motion.div>
            ))}
          </div>
        </div>

        {/* Social links */}
        <div className="mb-14">
          <h3 className="text-display-sm text-center mb-8">Connect &amp; Explore</h3>
          <div className="grid sm:grid-cols-3 gap-4">
            <a
              href="https://www.linkedin.com/in/ali-younes-41a2b4296/"
              target="_blank"
              rel="noopener noreferrer"
              className="block"
            >
              <GlassCard className="text-center py-5 min-h-11">
                <span className="text-2xl mb-2 block">&#128188;</span>
                <span className="font-medium text-white text-sm">LinkedIn</span>
              </GlassCard>
            </a>
            <a
              href="https://github.com/whoisaldo/Exerly-Fitness"
              target="_blank"
              rel="noopener noreferrer"
              className="block"
            >
              <GlassCard className="text-center py-5 min-h-11">
                <span className="text-2xl mb-2 block">&#128279;</span>
                <span className="font-medium text-white text-sm">GitHub Repo</span>
              </GlassCard>
            </a>
            <Link to="/status-check" className="block">
              <GlassCard className="text-center py-5 min-h-11">
                <span className="text-2xl mb-2 block">&#128202;</span>
                <span className="font-medium text-white text-sm">System Status</span>
              </GlassCard>
            </Link>
          </div>
        </div>

        {/* Footer / version info */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.5, duration: 0.5 }}
          className="text-center border-t border-border-subtle pt-8 pb-4"
        >
          <p className="text-sm text-slate-400 leading-relaxed max-w-lg mx-auto mb-4">
            Exerly is a passion project built to reshape the fitness experience with seamless UI,
            modern design, and scalable backend performance. More exciting features coming soon!
          </p>
          <div className="flex items-center justify-center gap-3 text-xs text-slate-600">
            <span>Version 1.0.0</span>
            <span>&bull;</span>
            <span>Built with &#10084;&#65039; in 2025</span>
          </div>
        </motion.div>
      </div>
    </PageTransition>
  );
};

export default Credits;
