import { useNavigate } from 'react-router-dom';
import { motion, useReducedMotion } from 'framer-motion';
import { ActionButton, PulseLine } from '../ui';

export function CTASection() {
  const navigate = useNavigate();
  const reduceMotion = useReducedMotion();

  return (
    <section className="border-t border-white/[0.08] py-20 lg:py-28">
      <div className="mx-auto max-w-3xl px-4 text-center sm:px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: reduceMotion ? 0 : 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
        >
          <PulseLine className="mx-auto mb-8 h-8 w-44 text-primary" />
          <h2 className="text-display-sm text-slate-50">Start tracking with precision</h2>
          <p className="mx-auto mt-4 max-w-xl text-lg text-slate-400">
            Set up your account in minutes and see your whole picture — training, food, sleep, and
            progress — in one place.
          </p>
          <div className="mt-9 flex flex-wrap justify-center gap-4">
            <ActionButton
              variant="primary"
              onClick={() => navigate('/login')}
              className="min-h-12 px-8 text-base"
            >
              Get started free
            </ActionButton>
            <ActionButton
              variant="secondary"
              onClick={() => navigate('/credits')}
              className="min-h-12 px-8 text-base"
            >
              About Exerly
            </ActionButton>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
