import { motion, useReducedMotion } from 'framer-motion';
import { PulseLine } from '../ui';

const WEEK_BARS = [42, 68, 35, 80, 58, 74, 92];

const STAT_TILES = [
  { value: '2,847', label: 'Calories' },
  { value: '8.5h', label: 'Sleep' },
  { value: '156g', label: 'Protein' },
];

/** Static, decorative recreation of the Exerly web dashboard. */
export function BrowserFrame({ className = '' }: { className?: string }) {
  const reduceMotion = useReducedMotion();

  return (
    <div
      aria-hidden="true"
      className={`overflow-hidden rounded-2xl border border-white/[0.1] bg-surface-1 shadow-glow-lg ${className}`}
    >
      {/* Window chrome */}
      <div className="flex items-center gap-2 border-b border-white/[0.08] px-4 py-3">
        <span className="h-2.5 w-2.5 rounded-full bg-white/[0.12]" />
        <span className="h-2.5 w-2.5 rounded-full bg-white/[0.12]" />
        <span className="h-2.5 w-2.5 rounded-full bg-white/[0.12]" />
        <span className="ml-3 rounded-md bg-white/[0.06] px-3 py-1 text-[11px] font-medium text-slate-500">
          exerly.fit/dashboard
        </span>
      </div>

      <div className="flex">
        {/* Sidebar rail */}
        <div className="hidden w-12 flex-col items-center gap-3 border-r border-white/[0.08] py-4 sm:flex">
          <span className="h-6 w-6 rounded-lg bg-primary" />
          <span className="mt-2 h-5 w-5 rounded-md bg-white/[0.1]" />
          <span className="h-5 w-5 rounded-md bg-white/[0.06]" />
          <span className="h-5 w-5 rounded-md bg-white/[0.06]" />
          <span className="h-5 w-5 rounded-md bg-white/[0.06]" />
        </div>

        {/* Main panel */}
        <div className="flex-1 p-4 sm:p-5">
          <div className="mb-4 flex items-baseline justify-between">
            <span className="text-sm font-semibold text-slate-100">Today</span>
            <span className="text-[11px] text-slate-500">Tuesday, Jul 2</span>
          </div>

          <div className="mb-4 grid grid-cols-3 gap-2.5">
            {STAT_TILES.map((s) => (
              <div
                key={s.label}
                className="rounded-xl border border-white/[0.08] bg-surface-2 p-3 text-center"
              >
                <div className="text-base font-bold tabular-nums text-slate-50 sm:text-lg">
                  {s.value}
                </div>
                <div className="mt-0.5 text-[10px] uppercase tracking-widest text-slate-500">
                  {s.label}
                </div>
              </div>
            ))}
          </div>

          {/* Weekly activity chart */}
          <div className="rounded-xl border border-white/[0.08] bg-surface-2 p-3.5">
            <div className="mb-2 flex items-center justify-between">
              <span className="text-[11px] font-medium text-slate-400">Weekly activity</span>
              <span className="text-[11px] font-semibold text-primary-bright">+12%</span>
            </div>
            <div className="flex h-16 items-end gap-1.5">
              {WEEK_BARS.map((h, i) => (
                <motion.span
                  key={i}
                  className="flex-1 rounded-t-sm bg-primary/70 last:bg-primary"
                  initial={reduceMotion ? { height: `${h}%` } : { height: 0 }}
                  whileInView={{ height: `${h}%` }}
                  viewport={{ once: true }}
                  transition={{ duration: 0.5, delay: 0.3 + i * 0.06, ease: [0.16, 1, 0.3, 1] }}
                />
              ))}
            </div>
            <PulseLine className="mt-2 h-5 w-full text-primary/50" strokeWidth={1.5} delay={0.8} />
          </div>
        </div>
      </div>
    </div>
  );
}
