import { useEffect, useRef, useState } from 'react';
import { useInView, useReducedMotion } from 'framer-motion';

const STATS = [
  { label: 'Active Users', target: 1247 },
  { label: 'Activities Tracked', target: 15680 },
  { label: 'Meals Logged', target: 8934 },
  { label: 'Sleep Hours Monitored', target: 2456 },
];

function useCountUp(target: number, start: boolean, duration = 1800) {
  const [value, setValue] = useState(0);

  useEffect(() => {
    if (!start) return;
    let frame: number;
    const t0 = performance.now();
    const tick = (now: number) => {
      const progress = Math.min((now - t0) / duration, 1);
      const eased = 1 - Math.pow(1 - progress, 3);
      setValue(Math.floor(target * eased));
      if (progress < 1) frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [start, target, duration]);

  return value;
}

function Stat({ label, target, start }: { label: string; target: number; start: boolean }) {
  const reduceMotion = useReducedMotion();
  const counted = useCountUp(target, start && !reduceMotion);
  const value = reduceMotion ? target : counted;

  return (
    <div className="py-2 text-center">
      <div className="text-3xl font-bold tabular-nums tracking-tight text-slate-50">
        {value.toLocaleString()}
      </div>
      <div className="label mt-2">{label}</div>
    </div>
  );
}

export function StatsBand() {
  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { once: true, amount: 0.4 });

  return (
    <section ref={ref} className="border-y border-white/[0.08] bg-surface-1">
      <div className="mx-auto grid max-w-6xl grid-cols-2 gap-6 px-4 py-10 sm:px-6 md:grid-cols-4 lg:px-8">
        {STATS.map((s) => (
          <Stat key={s.label} label={s.label} target={s.target} start={inView} />
        ))}
      </div>
    </section>
  );
}
