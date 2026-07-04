import { motion } from 'framer-motion';
import type { MotionValue } from 'framer-motion';
import type { Ripple } from './useSequencer';

interface DemoCursorProps {
  x: MotionValue<number>;
  y: MotionValue<number>;
  scale: MotionValue<number>;
  ripple: Ripple | null;
}

/** Fake macOS-style cursor + click ripple, positioned in canvas coordinates. */
export function DemoCursor({ x, y, scale, ripple }: DemoCursorProps) {
  return (
    <>
      {ripple && (
        <motion.span
          key={ripple.key}
          className="absolute z-10 h-8 w-8 rounded-full bg-primary/30"
          style={{ left: ripple.x, top: ripple.y, translateX: '-50%', translateY: '-50%' }}
          initial={{ scale: 0.3, opacity: 0.6 }}
          animate={{ scale: 1.8, opacity: 0 }}
          transition={{ duration: 0.45, ease: 'easeOut' }}
        />
      )}
      <motion.div
        className="absolute left-0 top-0 z-20 will-change-transform"
        style={{ x, y, scale }}
      >
        {/* Tip of the arrow sits at (1,1), close enough to the motion point. */}
        <svg
          width="19"
          height="22"
          viewBox="0 0 14 17"
          fill="none"
          className="overflow-visible drop-shadow-[0_2px_5px_rgba(0,0,0,0.6)]"
        >
          <path
            d="M1 1v12.6l3.1-2.7 1.9 4.3 2.3-1-1.9-4.2h4.2L1 1Z"
            fill="#f7f8fa"
            stroke="#0a0a0f"
            strokeWidth="1"
            strokeLinejoin="round"
          />
        </svg>
      </motion.div>
    </>
  );
}
