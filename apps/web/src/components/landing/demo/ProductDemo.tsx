import { useEffect, useRef, useState } from 'react';
import { motion, useInView, useReducedMotion } from 'framer-motion';
import { CANVAS_H, CANVAS_W, calorieCoachFlow } from './flows';
import { FINAL_STATE } from './demoState';
import { MiniDashboard } from './MiniDashboard';
import { DemoCursor } from './DemoCursor';
import { useSequencer } from './useSequencer';

function useMediaQuery(query: string): boolean {
  const [matches, setMatches] = useState(() => window.matchMedia(query).matches);
  useEffect(() => {
    const mql = window.matchMedia(query);
    const onChange = (event: MediaQueryListEvent) => setMatches(event.matches);
    setMatches(mql.matches);
    mql.addEventListener('change', onChange);
    return () => mql.removeEventListener('change', onChange);
  }, [query]);
  return matches;
}

function usePageVisible(): boolean {
  const [visible, setVisible] = useState(() => document.visibilityState !== 'hidden');
  useEffect(() => {
    const onChange = () => setVisible(document.visibilityState !== 'hidden');
    document.addEventListener('visibilitychange', onChange);
    return () => document.removeEventListener('visibilitychange', onChange);
  }, []);
  return visible;
}

/**
 * Self-playing product demo: a mocked mini Exerly dashboard inside browser
 * chrome, where a scripted fake cursor logs a meal and asks the AI coach on a
 * loop. Pauses off-screen, on hover, and in background tabs; renders a static
 * final frame under reduced motion or on small screens.
 */
export function ProductDemo() {
  const reduceMotion = useReducedMotion();
  const wide = useMediaQuery('(min-width: 640px)');
  const canHover = useMediaQuery('(hover: hover)');
  const animated = !reduceMotion && wide;

  const frameRef = useRef<HTMLDivElement>(null);
  const stageRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLDivElement>(null);
  const inView = useInView(frameRef, { amount: 0.3 });
  const [hovered, setHovered] = useState(false);
  const pageVisible = usePageVisible();
  const [scale, setScale] = useState(1);

  useEffect(() => {
    const stage = stageRef.current;
    if (!stage) return;
    const observer = new ResizeObserver(([entry]) => {
      setScale(entry.contentRect.width / CANVAS_W);
    });
    observer.observe(stage);
    return () => observer.disconnect();
  }, []);

  const { state, cursorX, cursorY, cursorScale, ripple } = useSequencer({
    flow: calorieCoachFlow,
    enabled: animated,
    playing: inView && !hovered && pageVisible,
    canvasRef,
  });
  const shown = animated ? state : FINAL_STATE;

  return (
    <div
      ref={frameRef}
      aria-hidden="true"
      onMouseEnter={canHover ? () => setHovered(true) : undefined}
      onMouseLeave={canHover ? () => setHovered(false) : undefined}
      className="mx-auto w-full max-w-[720px] select-none overflow-hidden rounded-2xl border border-white/[0.1] bg-surface-1 shadow-glow-lg"
    >
      {/* Window chrome — mirrors landing/BrowserFrame.tsx */}
      <div className="flex items-center gap-2 border-b border-white/[0.08] px-4 py-3">
        <span className="h-2.5 w-2.5 rounded-full bg-white/[0.12]" />
        <span className="h-2.5 w-2.5 rounded-full bg-white/[0.12]" />
        <span className="h-2.5 w-2.5 rounded-full bg-white/[0.12]" />
        <span className="ml-3 rounded-md bg-white/[0.06] px-3 py-1 text-[11px] font-medium text-slate-500">
          exerly.fit/dashboard
        </span>
      </div>

      {/* Stage reserves the exact aspect ratio at every width (zero layout shift);
          the fixed 720x430 canvas scales to fit so cursor math stays stable. */}
      <div
        ref={stageRef}
        className="relative w-full"
        style={{ aspectRatio: `${CANVAS_W} / ${CANVAS_H}` }}
      >
        <div
          ref={canvasRef}
          className="pointer-events-none absolute left-0 top-0 origin-top-left"
          style={{ width: CANVAS_W, height: CANVAS_H, transform: `scale(${scale})` }}
        >
          <motion.div
            className="relative h-full w-full"
            animate={{ opacity: shown.phase === 'fading' ? 0 : 1 }}
            transition={{ duration: shown.phase === 'fading' ? 0.35 : 0.25, ease: 'easeInOut' }}
          >
            <MiniDashboard state={shown} animateEntries={animated} />
            {animated && <DemoCursor x={cursorX} y={cursorY} scale={cursorScale} ripple={ripple} />}
          </motion.div>
        </div>
      </div>
    </div>
  );
}
