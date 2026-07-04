import { motion } from 'framer-motion';
import type { ReactNode } from 'react';
import { ProgressRing } from '../../ui';
import { GOAL_KCAL } from './demoState';
import type { DemoState, FoodEntry } from './demoState';
import type { TargetId } from './flows';

const EASE = [0.16, 1, 0.3, 1] as const;

/** Icon paths reused from FeaturesGrid so the rail matches the app's icon language. */
const NAV_ICONS = {
  overview: 'M3 3v18h18M7 15l4-4 3 3 6-7',
  food: 'M12 7c-3.5-2-7 .6-7 4.5C5 15.5 8 21 12 21s7-5.5 7-9.5c0-3.9-3.5-6.5-7-4.5Zm0 0V3m0 4c0-2 2-4 4-4',
  activity: 'M2 12h4l3-7 4 14 3-7h6',
  sleep: 'M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8Z',
};

const CHIP_TONES = {
  success: 'bg-success/15 text-success border-success/20',
  warning: 'bg-warning/15 text-warning border-warning/20',
  primary: 'bg-primary/15 text-primary-bright border-primary/20',
} as const;

/* Compact replica of ui/Badge — its size presets can't be overridden via className. */
function MacroChip({ tone, children }: { tone: keyof typeof CHIP_TONES; children: ReactNode }) {
  return (
    <span
      className={`inline-flex items-center rounded-full border px-1.5 py-px text-[10px] font-medium ${CHIP_TONES[tone]}`}
    >
      {children}
    </span>
  );
}

/* Non-interactive replica of ui/ActionButton primary — real button semantics are
   pointless inside this aria-hidden, pointer-events-none canvas. */
function DemoButton({ targetId, children }: { targetId: TargetId; children: ReactNode }) {
  return (
    <div
      data-demo-target={targetId}
      className="flex h-9 shrink-0 items-center justify-center rounded-xl bg-primary px-3.5 text-xs font-semibold text-white shadow-glow-primary"
    >
      {children}
    </div>
  );
}

function Caret({ tall = false }: { tall?: boolean }) {
  return (
    <span
      className={`ml-px inline-block w-px animate-pulse bg-primary-bright align-middle ${tall ? 'h-3.5' : 'h-3'}`}
    />
  );
}

interface FakeInputProps {
  targetId: TargetId;
  value: string;
  placeholder: string;
  focused: boolean;
  multiline?: boolean;
}

/** Input-look div mirroring Dashboard/Food.jsx field styling; scripted focus + caret. */
function FakeInput({ targetId, value, placeholder, focused, multiline = false }: FakeInputProps) {
  return (
    <div
      data-demo-target={targetId}
      className={`w-full overflow-hidden rounded-xl border bg-surface-2 px-3 text-xs transition-colors duration-200 ${
        multiline ? 'h-[50px] py-2' : 'flex h-9 items-center'
      } ${focused ? 'border-primary ring-1 ring-primary/50' : 'border-border-subtle'}`}
    >
      <span
        className={`${multiline ? 'break-words leading-[17px]' : 'whitespace-nowrap'} ${
          value ? 'text-slate-100' : 'text-slate-500'
        }`}
      >
        {value || placeholder}
        {focused && <Caret tall />}
      </span>
    </div>
  );
}

function EntryRow({ entry, animateIn }: { entry: FoodEntry; animateIn: boolean }) {
  return (
    <motion.div
      initial={animateIn ? { opacity: 0, y: 8, scale: 0.98 } : false}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      transition={{ duration: 0.45, ease: EASE }}
      className="rounded-xl bg-surface-1 p-2.5"
    >
      <div className="flex items-center justify-between gap-2">
        <p className="truncate text-xs font-medium text-slate-100">
          <span className="mr-1.5">{entry.emoji}</span>
          {entry.name}
        </p>
        <span className="shrink-0 text-[11px] font-semibold tabular-nums text-slate-300">
          {entry.cal} cal
        </span>
      </div>
      <div className="mt-1.5 flex gap-1.5">
        <MacroChip tone="success">P: {entry.p}g</MacroChip>
        <MacroChip tone="warning">C: {entry.c}g</MacroChip>
        <MacroChip tone="primary">F: {entry.f}g</MacroChip>
      </div>
    </motion.div>
  );
}

const SUGGESTIONS = ['How can I improve my squat form?', 'What should I eat before a workout?'];

interface MiniDashboardProps {
  state: DemoState;
  /** false for the static (reduced-motion / small screen) render. */
  animateEntries?: boolean;
}

/**
 * Scaled-down, fully mocked recreation of the Exerly dashboard for the landing
 * demo. Pure render of DemoState; styling mirrors Dashboard/Food.jsx and
 * AICoach/AICoach.jsx recipes. Every dynamic region has a fixed box so nothing
 * ever shifts layout.
 */
export function MiniDashboard({ state, animateEntries = false }: MiniDashboardProps) {
  const seededMaxId = 2;
  const pct = Math.round((state.consumed / GOAL_KCAL) * 100);
  const protein = state.entries.reduce((sum, e) => sum + e.p, 0);
  const carbs = state.entries.reduce((sum, e) => sum + e.c, 0);
  const fat = state.entries.reduce((sum, e) => sum + e.f, 0);

  const navItems: Array<{ key: keyof typeof NAV_ICONS; targetId?: TargetId; active: boolean }> = [
    { key: 'overview', active: state.activeNav === 'home' },
    { key: 'food', targetId: 'nav-food', active: state.activeNav === 'food' },
    { key: 'activity', active: false },
    { key: 'sleep', active: false },
  ];

  return (
    <div className="grid h-full w-full grid-cols-[40px_1.2fr_1fr] gap-3 bg-surface-1 p-4">
      {/* Nav rail */}
      <div className="flex flex-col items-center gap-2">
        <span className="flex h-7 w-7 items-center justify-center rounded-lg bg-gradient-primary text-[11px] font-bold text-white">
          E
        </span>
        <div className="mt-1 flex flex-col gap-1.5">
          {navItems.map((item) => (
            <span
              key={item.key}
              data-demo-target={item.targetId}
              className={`flex h-7 w-7 items-center justify-center rounded-md transition-colors duration-300 ${
                item.active ? 'bg-primary/15 text-primary-bright' : 'text-slate-600'
              }`}
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
                <path
                  d={NAV_ICONS[item.key]}
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </span>
          ))}
        </div>
      </div>

      {/* Calorie log */}
      <div className="glass flex min-h-0 flex-col p-4">
        <div className="flex items-baseline justify-between">
          <span className="text-sm font-semibold text-slate-100">Today</span>
          <span className="text-[11px] text-slate-500">Friday, Jul 3</span>
        </div>

        <div className="mt-3 flex items-center gap-4">
          <ProgressRing value={pct} size={88} strokeWidth={7} label="of 2,200" />
          <div className="min-w-0">
            <div className="label">Consumed</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-slate-50">
              <motion.span
                key={state.consumed}
                initial={animateEntries ? { opacity: 0, y: 6 } : false}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.4, ease: EASE }}
                className="inline-block"
              >
                {state.consumed.toLocaleString('en-US')}
              </motion.span>{' '}
              <span className="text-xs font-medium text-slate-500">kcal</span>
            </div>
            <div className="mt-1 text-[11px] tabular-nums text-slate-500">
              P {protein}g · C {carbs}g · F {fat}g
            </div>
          </div>
        </div>

        <div className="mt-3 min-h-0 flex-1 space-y-2 overflow-hidden">
          {state.entries.map((entry) => (
            <EntryRow
              key={entry.id}
              entry={entry}
              animateIn={animateEntries && entry.id > seededMaxId}
            />
          ))}
        </div>

        <div className="mt-3 flex items-center gap-2">
          <FakeInput
            targetId="food-input"
            value={state.foodInput}
            placeholder="e.g., Grilled Chicken Breast"
            focused={state.focused === 'food'}
          />
          <DemoButton targetId="food-add">Add</DemoButton>
        </div>
      </div>

      {/* AI coach */}
      <div className="glass flex min-h-0 flex-col p-4">
        <div className="flex items-center gap-2">
          <span className="flex h-7 w-7 items-center justify-center rounded-lg bg-gradient-primary">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none">
              <path
                d="M13 2 3 14h7l-1 8 10-12h-7l1-8Z"
                fill="currentColor"
                className="text-white"
              />
            </svg>
          </span>
          <span className="text-sm font-semibold text-slate-100">AI Coach</span>
          <span className="ml-auto">
            <MacroChip tone="primary">{state.question ? '4/5' : '5/5'} credits</MacroChip>
          </span>
        </div>

        <div className="mt-3 flex min-h-0 flex-1 flex-col gap-2 overflow-hidden">
          {!state.question ? (
            <>
              <span className="text-[11px] text-slate-600">Try asking</span>
              {SUGGESTIONS.map((s) => (
                <span
                  key={s}
                  className="w-fit rounded-lg bg-surface-1 px-2.5 py-1.5 text-[11px] text-slate-400"
                >
                  {s}
                </span>
              ))}
            </>
          ) : (
            <>
              <motion.div
                initial={animateEntries ? { opacity: 0, y: 6 } : false}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.3, ease: EASE }}
                className="ml-auto w-fit max-w-[85%] rounded-xl rounded-br-sm bg-primary/15 px-3 py-2 text-xs text-slate-100"
              >
                {state.question}
              </motion.div>
              {state.thinking && (
                <div className="flex w-fit items-center gap-1 rounded-xl rounded-bl-sm bg-surface-1 px-3 py-2.5">
                  {[0, 1, 2].map((i) => (
                    <span
                      key={i}
                      className="h-1.5 w-1.5 animate-pulse rounded-full bg-slate-500"
                      style={{ animationDelay: `${i * 160}ms` }}
                    />
                  ))}
                </div>
              )}
              {state.reply && (
                <div className="whitespace-pre-wrap rounded-xl rounded-bl-sm bg-surface-1 px-3 py-2.5 text-xs leading-relaxed text-slate-300">
                  {state.reply}
                  {!state.replyDone && <Caret />}
                </div>
              )}
            </>
          )}
        </div>

        <div className="mt-3 flex items-end gap-2">
          <FakeInput
            targetId="coach-input"
            value={state.coachInput}
            placeholder="Type your question here..."
            focused={state.focused === 'coach'}
            multiline
          />
          <DemoButton targetId="coach-send">Ask Coach</DemoButton>
        </div>
      </div>
    </div>
  );
}
