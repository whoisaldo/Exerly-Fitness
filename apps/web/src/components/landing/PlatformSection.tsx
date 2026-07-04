import { useNavigate } from 'react-router-dom';
import { motion, useReducedMotion } from 'framer-motion';
import { ActionButton } from '../ui';
import { IPhoneFrame } from './IPhoneFrame';

const IOS_FEATURES = [
  'Apple Health sync — steps, workouts, and calories flow in automatically',
  'Barcode scanner for instant food logging',
  'Personalized onboarding that builds your calorie and macro plan',
  'Log activities, meals, and sleep in seconds from anywhere',
];

export function PlatformSection() {
  const navigate = useNavigate();
  const reduceMotion = useReducedMotion();

  return (
    <section id="platforms" className="border-y border-white/[0.08] bg-surface-1 py-20 lg:py-28">
      <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
        <motion.div
          className="mx-auto mb-16 max-w-2xl text-center"
          initial={{ opacity: 0, y: reduceMotion ? 0 : 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
        >
          <h2 className="text-display-sm text-slate-50">One account. Every screen.</h2>
          <p className="mt-3 text-lg text-slate-400">
            The full dashboard in your browser today — and a native iOS app on the way.
          </p>
        </motion.div>

        <div className="grid items-center gap-14 lg:grid-cols-2 lg:gap-20">
          {/* iPhone showcase */}
          <motion.div
            initial={{ opacity: 0, y: reduceMotion ? 0 : 28 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
            className="flex justify-center"
          >
            <IPhoneFrame />
          </motion.div>

          {/* iOS copy */}
          <motion.div
            initial={{ opacity: 0, y: reduceMotion ? 0 : 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5, delay: 0.15 }}
          >
            <span className="inline-flex items-center gap-2 rounded-full border border-primary/25 bg-primary/10 px-4 py-1.5 text-xs font-semibold text-primary-bright">
              <svg
                width="12"
                height="12"
                viewBox="0 0 24 24"
                fill="currentColor"
                aria-hidden="true"
              >
                <path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8.79-.16 2.31-.94 3.9-.8 1.9.15 3.34.9 4.29 2.28-3.95 2.37-3.31 7.16.73 8.72-.65 1.4-1.47 2.77-3 3.97ZM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25Z" />
              </svg>
              Coming soon to the App Store
            </span>

            <h3 className="mt-5 text-2xl font-bold tracking-tight text-slate-50">Exerly for iOS</h3>
            <p className="mt-3 max-w-lg leading-relaxed text-slate-400">
              The same account and the same data, built natively for iPhone — designed for logging
              on the move and syncing with the health tools you already use.
            </p>

            <ul className="mt-7 space-y-3.5">
              {IOS_FEATURES.map((f) => (
                <li key={f} className="flex items-start gap-3 text-slate-300">
                  <svg
                    width="18"
                    height="18"
                    viewBox="0 0 24 24"
                    fill="none"
                    aria-hidden="true"
                    className="mt-0.5 shrink-0 text-primary"
                  >
                    <path
                      d="M20 6L9 17l-5-5"
                      stroke="currentColor"
                      strokeWidth="2.5"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  </svg>
                  <span className="leading-relaxed">{f}</span>
                </li>
              ))}
            </ul>

            <div className="mt-9 flex flex-wrap items-center gap-4">
              <ActionButton variant="primary" onClick={() => navigate('/login')}>
                Use Exerly on the web
              </ActionButton>
              <span className="text-sm text-slate-500">Free while in beta</span>
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  );
}
