import { motion, useReducedMotion } from 'framer-motion';

const FEATURES = [
  {
    title: 'Smart Activity Tracking',
    description:
      'Track workouts, runs, and daily activities with intelligent categorization and intensity monitoring.',
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
    title: 'Nutrition Management',
    description:
      'Log meals with detailed macro tracking including protein, carbs, fat, and sugar monitoring.',
    icon: (
      <path
        d="M12 7c-3.5-2-7 .6-7 4.5C5 15.5 8 21 12 21s7-5.5 7-9.5c0-3.9-3.5-6.5-7-4.5Zm0 0V3m0 4c0-2 2-4 4-4"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    ),
  },
  {
    title: 'Sleep Analytics',
    description: 'Monitor sleep patterns with bedtime and wake time tracking for optimal recovery.',
    icon: (
      <path
        d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8Z"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    ),
  },
  {
    title: 'Progress Dashboard',
    description:
      'Comprehensive analytics with goal tracking, progress charts, and personalized insights.',
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
];

export function FeaturesGrid() {
  const reduceMotion = useReducedMotion();

  return (
    <section id="features" className="py-20 lg:py-28">
      <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
        <motion.div
          className="mx-auto mb-14 max-w-2xl text-center"
          initial={{ opacity: 0, y: reduceMotion ? 0 : 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
        >
          <h2 className="text-display-sm text-slate-50">Everything that moves the needle</h2>
          <p className="mt-3 text-lg text-slate-400">
            Track, analyze, and optimize your health without fighting the tool.
          </p>
        </motion.div>

        <div className="grid gap-5 sm:grid-cols-2">
          {FEATURES.map((feature, i) => (
            <motion.div
              key={feature.title}
              initial={{ opacity: 0, y: reduceMotion ? 0 : 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.08, duration: 0.5 }}
              className="group rounded-2xl border border-white/[0.08] bg-surface-2 p-7 transition-all duration-300 hover:-translate-y-0.5 hover:border-white/[0.14]"
            >
              <span className="mb-5 flex h-11 w-11 items-center justify-center rounded-xl bg-primary/10 text-primary transition-colors duration-300 group-hover:bg-primary/15">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                  {feature.icon}
                </svg>
              </span>
              <h3 className="text-lg font-semibold text-slate-50">{feature.title}</h3>
              <p className="mt-2 leading-relaxed text-slate-400">{feature.description}</p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
