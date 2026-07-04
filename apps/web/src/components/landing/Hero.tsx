import { useNavigate } from 'react-router-dom';
import { motion, useReducedMotion, type Variants } from 'framer-motion';
import { ActionButton, PulseLine } from '../ui';
import { BrowserFrame } from './BrowserFrame';
import { IPhoneFrame } from './IPhoneFrame';

export function Hero() {
  const navigate = useNavigate();
  const reduceMotion = useReducedMotion();

  const container: Variants = {
    hidden: {},
    show: { transition: { staggerChildren: reduceMotion ? 0 : 0.09 } },
  };
  const item: Variants = {
    hidden: { opacity: 0, y: reduceMotion ? 0 : 16 },
    show: { opacity: 1, y: 0, transition: { duration: 0.55, ease: [0.16, 1, 0.3, 1] } },
  };

  return (
    <section className="relative pb-24 pt-16 lg:pb-32 lg:pt-24">
      <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
        <div className="grid items-center gap-14 lg:grid-cols-[1fr_1.05fr] lg:gap-10">
          {/* Copy */}
          <motion.div variants={container} initial="hidden" animate="show">
            <motion.div
              variants={item}
              className="mb-6 inline-flex items-center gap-2 rounded-full border border-white/[0.1] bg-surface-2 px-4 py-1.5 text-xs font-medium text-slate-300"
            >
              <span className="h-1.5 w-1.5 rounded-full bg-primary" />
              Now on the web — iOS coming soon
            </motion.div>

            <motion.h1 variants={item} className="text-display-sm text-slate-50 sm:text-display">
              Fitness, precisely tracked.
            </motion.h1>

            <motion.div variants={item}>
              <PulseLine className="mt-5 h-8 w-56 text-primary" delay={0.4} />
            </motion.div>

            <motion.p
              variants={item}
              className="mt-6 max-w-xl text-lg leading-relaxed text-slate-400"
            >
              Exerly brings your activities, nutrition, sleep, and goals into one clear dashboard —
              with an AI coach that turns the numbers into direction.
            </motion.p>

            <motion.div variants={item} className="mt-9 flex flex-wrap gap-4">
              <ActionButton
                variant="primary"
                onClick={() => navigate('/login')}
                className="min-h-11 px-7 text-base"
              >
                Get started free
                <span aria-hidden="true" className="ml-1">
                  &rarr;
                </span>
              </ActionButton>
              <ActionButton
                variant="secondary"
                onClick={() => navigate('/login')}
                className="min-h-11 px-7 text-base"
              >
                Open the dashboard
              </ActionButton>
            </motion.div>
          </motion.div>

          {/* Dual-device showcase */}
          <motion.div
            initial={{ opacity: 0, y: reduceMotion ? 0 : 28 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, delay: 0.25, ease: [0.16, 1, 0.3, 1] }}
            className="relative hidden lg:block"
          >
            <BrowserFrame className="max-w-xl" />
            <IPhoneFrame className="absolute -bottom-14 -right-2 z-10 scale-[0.82] xl:right-0" />
          </motion.div>
        </div>
      </div>
    </section>
  );
}
