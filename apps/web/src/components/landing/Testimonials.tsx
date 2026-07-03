import { motion, useReducedMotion } from 'framer-motion';

const TESTIMONIALS = [
  {
    text: 'Exerly has transformed how I track my fitness journey. The interface is intuitive and the analytics are incredibly detailed.',
    author: 'Sarah Chen',
    role: 'Fitness Enthusiast',
  },
  {
    text: 'The macro tracking feature is exactly what I needed for my nutrition goals. Clean, simple, and effective.',
    author: 'Mike Rodriguez',
    role: 'Health Coach',
  },
  {
    text: "I've tried every tracker out there. Exerly is the first one where logging takes seconds instead of minutes, so I actually stick with it.",
    author: 'Alex Thompson',
    role: 'Full-Stack Developer',
  },
];

export function Testimonials() {
  const reduceMotion = useReducedMotion();

  return (
    <section className="py-20 lg:py-28">
      <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
        <motion.div
          className="mx-auto mb-14 max-w-2xl text-center"
          initial={{ opacity: 0, y: reduceMotion ? 0 : 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
        >
          <h2 className="text-display-sm text-slate-50">What users say</h2>
          <p className="mt-3 text-lg text-slate-400">
            Feedback from fitness enthusiasts and health professionals.
          </p>
        </motion.div>

        <div className="grid gap-5 md:grid-cols-3">
          {TESTIMONIALS.map((t, i) => (
            <motion.figure
              key={t.author}
              initial={{ opacity: 0, y: reduceMotion ? 0 : 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.1, duration: 0.5 }}
              className="flex h-full flex-col rounded-2xl border border-white/[0.08] bg-surface-2 p-7"
            >
              <svg
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="currentColor"
                aria-hidden="true"
                className="mb-4 text-primary/40"
              >
                <path d="M10 8c-3 0-5 2.2-5 5.1C5 15.9 6.9 18 9.4 18c2.1 0 3.6-1.5 3.6-3.5 0-1.9-1.4-3.3-3.2-3.3-.3 0-.7 0-.9.1C9.4 9.9 10.5 9 12 8.7L10 8Zm9 0c-3 0-5 2.2-5 5.1 0 2.8 1.9 4.9 4.4 4.9 2.1 0 3.6-1.5 3.6-3.5 0-1.9-1.4-3.3-3.2-3.3-.3 0-.7 0-.9.1.5-1.4 1.6-2.3 3.1-2.6L19 8Z" />
              </svg>
              <blockquote className="flex-1 leading-relaxed text-slate-300">{t.text}</blockquote>
              <figcaption className="mt-6 border-t border-white/[0.08] pt-4">
                <div className="text-sm font-semibold text-slate-100">{t.author}</div>
                <div className="mt-0.5 text-xs text-slate-500">{t.role}</div>
              </figcaption>
            </motion.figure>
          ))}
        </div>
      </div>
    </section>
  );
}
