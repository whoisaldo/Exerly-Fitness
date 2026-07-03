import { motion, useReducedMotion } from 'framer-motion';

interface PulseLineProps {
  className?: string;
  animate?: boolean;
  strokeWidth?: number;
  delay?: number;
}

/**
 * The Exerly signature motif: a thin EKG pulse line, drawn on when it
 * enters the viewport. Color comes from `currentColor` — set it with a
 * text-* class. Stretches to its container width.
 */
const PULSE_PATH = 'M2 20 H58 L66 20 L72 6 L80 34 L86 2 L92 30 L98 20 L112 20 L120 13 L128 20 H198';

export function PulseLine({
  className = '',
  animate = true,
  strokeWidth = 2,
  delay = 0,
}: PulseLineProps) {
  const reduceMotion = useReducedMotion();
  const shouldAnimate = animate && !reduceMotion;

  return (
    <svg
      viewBox="0 0 200 40"
      preserveAspectRatio="none"
      fill="none"
      aria-hidden="true"
      className={className}
    >
      <motion.path
        d={PULSE_PATH}
        stroke="currentColor"
        strokeWidth={strokeWidth}
        strokeLinecap="round"
        strokeLinejoin="round"
        vectorEffect="non-scaling-stroke"
        initial={shouldAnimate ? { pathLength: 0, opacity: 0 } : undefined}
        whileInView={shouldAnimate ? { pathLength: 1, opacity: 1 } : undefined}
        viewport={{ once: true, amount: 0.4 }}
        transition={{ duration: 1.4, delay, ease: [0.65, 0, 0.35, 1] }}
      />
    </svg>
  );
}
