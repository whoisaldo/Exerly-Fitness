import React from 'react';
import { Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import { GlassCard, ActionButton, PageTransition, ExerlyMark, PulseLine } from './ui';

const featureCards = [
  {
    title: 'Smart Tracking',
    desc: 'Intelligent activity and nutrition tracking with personalized insights',
    icon: (
      <path
        d="M2 12h4l3-7 4 14 3-7h6"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    ),
  },
  {
    title: 'Analytics Dashboard',
    desc: 'Comprehensive data visualization and progress monitoring',
    icon: (
      <path
        d="M3 3v18h18M7 15l4-4 3 3 6-7"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    ),
  },
  {
    title: 'AI Coaching',
    desc: 'A personal coach that turns your numbers into a plan you can follow',
    icon: (
      <path
        d="M12 3l1.9 5.1L19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9L12 3Zm7 11l.9 2.6L22.5 18l-2.6.9L19 21.5l-.9-2.6L15.5 18l2.6-1.4L19 14Z"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    ),
  },
  {
    title: 'Secure & Private',
    desc: 'Your data is protected with enterprise-grade security',
    icon: (
      <path
        d="M12 3l8 3v6c0 4.5-3.4 8.1-8 9-4.6-.9-8-4.5-8-9V6l8-3Zm-3 9l2.2 2.2L15.5 10"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    ),
  },
];

const Credits = () => {
  return (
    <PageTransition className="min-h-screen bg-deep text-slate-100">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
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
          <div className="flex justify-center mb-6">
            <ExerlyMark size={64} withWordmark={false} />
          </div>
          <h1 className="text-display-sm sm:text-display mb-3 text-slate-50">About Exerly</h1>
          <p className="text-lg text-slate-400">
            Fitness, precisely tracked &mdash; on the web today, on iOS soon.
          </p>
          <PulseLine className="mx-auto mt-6 h-7 w-44 text-primary" />
        </motion.div>

        {/* Org section */}
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.15, duration: 0.5 }}
          className="mb-14"
        >
          <GlassCard elevated className="text-center py-8 rounded-2xl">
            <p className="label mb-3">Built and maintained by</p>
            <h2 className="text-2xl font-bold text-slate-50 mb-2">Eternal Reverse</h2>
            <p className="text-slate-400 mb-5">
              The studio behind Exerly, focused on precise, humane software.
            </p>
            <a
              href="https://eternalreverse.dev"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 text-sm font-medium text-primary-bright transition-colors hover:text-slate-50"
            >
              eternalreverse.dev
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                <path
                  d="M7 17L17 7M9 7h8v8"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </a>
          </GlassCard>
        </motion.div>

        {/* Feature highlights */}
        <div className="mb-14">
          <h3 className="text-display-sm text-center mb-8 text-slate-50">
            What makes Exerly special?
          </h3>
          <div className="grid sm:grid-cols-2 gap-5">
            {featureCards.map((f, i) => (
              <motion.div
                key={f.title}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.2 + i * 0.08, duration: 0.5 }}
              >
                <GlassCard className="h-full">
                  <span className="mb-4 flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10 text-primary">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                      {f.icon}
                    </svg>
                  </span>
                  <h4 className="font-semibold text-slate-50 mb-1">{f.title}</h4>
                  <p className="text-sm text-slate-400 leading-relaxed">{f.desc}</p>
                </GlassCard>
              </motion.div>
            ))}
          </div>
        </div>

        {/* Links */}
        <div className="mb-14">
          <h3 className="text-display-sm text-center mb-8 text-slate-50">Connect &amp; Explore</h3>
          <div className="grid sm:grid-cols-2 gap-4">
            <a
              href="https://eternalreverse.dev"
              target="_blank"
              rel="noopener noreferrer"
              className="block"
            >
              <GlassCard className="text-center py-5 min-h-11">
                <span className="mx-auto mb-2 flex h-8 w-8 items-center justify-center text-primary">
                  <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                    <path
                      d="M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Zm0 0c2.5-2 4-5.5 4-9s-1.5-7-4-9m0 18c-2.5-2-4-5.5-4-9s1.5-7 4-9M3.5 9h17M3.5 15h17"
                      stroke="currentColor"
                      strokeWidth="1.8"
                      strokeLinecap="round"
                    />
                  </svg>
                </span>
                <span className="font-medium text-slate-100 text-sm">Eternal Reverse</span>
              </GlassCard>
            </a>
            <Link to="/status-check" className="block">
              <GlassCard className="text-center py-5 min-h-11">
                <span className="mx-auto mb-2 flex h-8 w-8 items-center justify-center text-primary">
                  <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                    <path
                      d="M22 12h-4l-3 8-6-16-3 8H2"
                      stroke="currentColor"
                      strokeWidth="2"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  </svg>
                </span>
                <span className="font-medium text-slate-100 text-sm">System Status</span>
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
            Exerly is built to reshape the fitness experience with a seamless, readable interface
            and dependable performance. More features are on the way.
          </p>
          <div className="flex items-center justify-center gap-3 text-xs text-slate-500">
            <span>Version 1.0.0</span>
            <span>&bull;</span>
            <span>&copy; 2026 Eternal Reverse</span>
          </div>
        </motion.div>
      </div>
    </PageTransition>
  );
};

export default Credits;
