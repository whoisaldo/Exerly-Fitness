import { motion, useReducedMotion } from 'framer-motion';
import { PhoneLoggingVideo } from './PhoneLoggingVideo';

export function DemoSection() {
  const reduceMotion = useReducedMotion();

  return (
    <section aria-label="Exerly product demo" className="py-20 lg:py-28">
      <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
        <motion.div
          className="mx-auto mb-14 max-w-2xl text-center"
          initial={reduceMotion ? false : { opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: reduceMotion ? 0 : 0.5 }}
        >
          <h2 className="text-display-sm text-slate-50">A few taps. A clearer day.</h2>
          <p className="mt-3 text-lg text-slate-400">
            See how logging a meal works on iPhone, from choosing your portion to updating your
            diary.
          </p>
        </motion.div>

        <motion.div
          initial={reduceMotion ? false : { opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: reduceMotion ? 0 : 0.55, ease: [0.16, 1, 0.3, 1] }}
        >
          <PhoneLoggingVideo />
        </motion.div>
      </div>
    </section>
  );
}
