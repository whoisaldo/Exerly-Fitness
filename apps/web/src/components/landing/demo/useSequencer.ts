import { useEffect, useReducer, useRef, useState } from 'react';
import { animate, useMotionValue } from 'framer-motion';
import type { AnimationPlaybackControls, MotionValue } from 'framer-motion';
import type { RefObject } from 'react';
import { CANVAS_H, CANVAS_W } from './flows';
import type { Flow, Step, StepAction, TargetId } from './flows';
import { demoReducer, INITIAL_STATE } from './demoState';
import type { DemoEvent, DemoState } from './demoState';

export interface Ripple {
  key: number;
  x: number;
  y: number;
}

interface SequencerOptions {
  flow: Flow;
  /** false = the loop never starts (reduced motion / small screens). */
  enabled: boolean;
  /** Live gate: in view, not hovered, tab visible. Pausing never mutates demo state. */
  playing: boolean;
  /** The fixed 720x430 canvas the targets live in (may be scaled via transform). */
  canvasRef: RefObject<HTMLDivElement | null>;
}

interface Sequencer {
  state: DemoState;
  cursorX: MotionValue<number>;
  cursorY: MotionValue<number>;
  cursorScale: MotionValue<number>;
  ripple: Ripple | null;
}

/** Where the cursor rests between loops. */
const HOME = { x: CANVAS_W * 0.55, y: CANVAS_H * 0.82 };

const SPRING = { type: 'spring', stiffness: 170, damping: 20, mass: 0.9 } as const;

const ACTION_EVENTS: Record<StepAction, DemoEvent> = {
  openLog: { type: 'openLog' },
  focusFood: { type: 'focus', field: 'food' },
  addFood: { type: 'addFood' },
  focusCoach: { type: 'focus', field: 'coach' },
  askCoach: { type: 'askCoach' },
};

/**
 * Drives a Flow: an async runner walks the steps, moving the cursor MotionValues
 * (outside React render) and dispatching reducer events for the mini-app state.
 *
 * Pause works through two cooperating primitives: a gate promise parks discrete
 * waits (typing ticks, streams, sleeps) and AnimationPlaybackControls.pause()
 * freezes in-flight cursor glides. Cancellation (unmount / StrictMode remount /
 * HMR) is checked after every await before touching shared refs.
 */
export function useSequencer({ flow, enabled, playing, canvasRef }: SequencerOptions): Sequencer {
  const [state, dispatch] = useReducer(demoReducer, INITIAL_STATE);
  const [ripple, setRipple] = useState<Ripple | null>(null);
  const cursorX = useMotionValue(HOME.x);
  const cursorY = useMotionValue(HOME.y);
  const cursorScale = useMotionValue(1);

  const flowRef = useRef(flow);
  flowRef.current = flow;
  const playingRef = useRef(playing);
  const resumers = useRef<Array<() => void>>([]);
  const activeAnims = useRef<AnimationPlaybackControls[]>([]);

  useEffect(() => {
    playingRef.current = playing;
    if (playing) {
      resumers.current.splice(0).forEach((resume) => resume());
      activeAnims.current.forEach((anim) => anim.play());
    } else {
      activeAnims.current.forEach((anim) => anim.pause());
    }
  }, [playing]);

  useEffect(() => {
    if (!enabled) return;
    const signal = { cancelled: false };
    const parkedResumers = resumers.current; // stable array instance, only ever mutated
    let rippleKey = 0;

    const gate = () =>
      playingRef.current || signal.cancelled
        ? Promise.resolve()
        : new Promise<void>((resolve) => resumers.current.push(resolve));

    const rawTimeout = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

    /** Chunked + gate-aware so long waits pause promptly and can't pile up. */
    async function sleep(ms: number) {
      const end = performance.now() + ms;
      while (performance.now() < end && !signal.cancelled) {
        await rawTimeout(Math.min(100, end - performance.now()));
        await gate();
      }
    }

    /** Center of a target in canvas coordinates; live rect ratio undoes the stage scale. */
    function targetPoint(id: TargetId) {
      const canvas = canvasRef.current;
      const el = canvas?.querySelector(`[data-demo-target="${id}"]`);
      if (!canvas || !el) return null;
      const c = canvas.getBoundingClientRect();
      const r = el.getBoundingClientRect();
      const s = c.width / CANVAS_W || 1;
      return {
        x: (r.left - c.left + r.width / 2) / s,
        y: (r.top - c.top + r.height / 2) / s,
      };
    }

    async function glideTo(target: TargetId) {
      const point = targetPoint(target);
      if (!point) return;
      const anims = [animate(cursorX, point.x, SPRING), animate(cursorY, point.y, SPRING)];
      activeAnims.current = anims;
      if (!playingRef.current) anims.forEach((anim) => anim.pause());
      await Promise.all(anims);
      if (signal.cancelled) return;
      activeAnims.current = [];
    }

    async function press(step: Extract<Step, { type: 'click' }>) {
      const dip = animate(cursorScale, 0.82, { duration: 0.09 });
      activeAnims.current = [dip];
      await dip;
      if (signal.cancelled) return;
      setRipple({ key: ++rippleKey, x: cursorX.get(), y: cursorY.get() });
      if (step.action) dispatch(ACTION_EVENTS[step.action]);
      const rise = animate(cursorScale, 1, { duration: 0.12 });
      activeAnims.current = [rise];
      await rise;
      if (signal.cancelled) return;
      activeAnims.current = [];
    }

    async function exec(step: Step) {
      switch (step.type) {
        case 'wait':
          await sleep(step.ms);
          return;
        case 'moveTo':
          await glideTo(step.target);
          return;
        case 'click':
          await press(step);
          return;
        case 'type':
          for (let i = 1; i <= step.text.length; i++) {
            await sleep(38 + Math.random() * 45);
            if (signal.cancelled) return;
            dispatch({ type: 'input', field: step.field, value: step.text.slice(0, i) });
          }
          return;
        case 'stream': {
          const words = step.text.split(' ');
          for (let i = 0; i < words.length; i++) {
            await sleep(60 + Math.random() * 40);
            if (signal.cancelled) return;
            dispatch({ type: 'appendReply', chunk: (i === 0 ? '' : ' ') + words[i] });
          }
          dispatch({ type: 'replyDone' });
          return;
        }
      }
    }

    async function run() {
      while (!signal.cancelled) {
        dispatch({ type: 'reset' });
        setRipple(null);
        cursorX.jump(HOME.x);
        cursorY.jump(HOME.y);
        cursorScale.jump(1);
        for (const step of flowRef.current.steps) {
          await gate();
          if (signal.cancelled) return;
          await exec(step);
          if (signal.cancelled) return;
        }
        dispatch({ type: 'setPhase', phase: 'fading' });
        await sleep(420); // covers the 350ms fade; the reset above happens while invisible
      }
    }

    run();

    return () => {
      signal.cancelled = true;
      activeAnims.current.forEach((anim) => anim.stop());
      activeAnims.current = [];
      parkedResumers.splice(0).forEach((resume) => resume());
    };
  }, [enabled, canvasRef, cursorX, cursorY, cursorScale]);

  return { state, cursorX, cursorY, cursorScale, ripple };
}
