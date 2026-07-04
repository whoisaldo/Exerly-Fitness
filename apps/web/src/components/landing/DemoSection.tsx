import { motion, useReducedMotion } from 'framer-motion';
import { ProductDemo } from './demo/ProductDemo';

export function DemoSection() {
  const reduceMotion = useReducedMotion();

  return (
    <section aria-label="Exerly product demo" className="py-20 lg:py-28">
      <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
        <motion.div
          className="mx-auto mb-14 max-w-2xl text-center"
          initial={{ opacity: 0, y: reduceMotion ? 0 : 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
        >
          <h2 className="text-display-sm text-slate-50">Your day, logged in seconds</h2>
          <p className="mt-3 text-lg text-slate-400">
            Watch Exerly log a meal, update your targets, and turn the numbers into coaching.
          </p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: reduceMotion ? 0 : 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.55, ease: [0.16, 1, 0.3, 1] }}
        >
          <ProductDemo />
        </motion.div>
      </div>
    </section>
  );
}
