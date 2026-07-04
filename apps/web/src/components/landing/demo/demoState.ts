import { COACH_QUESTION, COACH_REPLY, FOOD_TEXT } from './flows';
import type { TypedField } from './flows';

export interface FoodEntry {
  id: number;
  name: string;
  cal: number;
  p: number;
  c: number;
  f: number;
  emoji: string;
}

export interface DemoState {
  activeNav: 'home' | 'food';
  foodInput: string;
  coachInput: string;
  focused: TypedField | null;
  entries: FoodEntry[];
  consumed: number;
  question: string | null;
  reply: string;
  replyDone: boolean;
  thinking: boolean;
  phase: 'playing' | 'fading';
}

export type DemoEvent =
  | { type: 'input'; field: TypedField; value: string }
  | { type: 'focus'; field: TypedField | null }
  | { type: 'openLog' }
  | { type: 'addFood' }
  | { type: 'askCoach' }
  | { type: 'appendReply'; chunk: string }
  | { type: 'replyDone' }
  | { type: 'setPhase'; phase: DemoState['phase'] }
  | { type: 'reset' };

export const GOAL_KCAL = 2200;

const SEEDED_ENTRIES: FoodEntry[] = [
  { id: 1, name: 'Oatmeal with berries', cal: 320, p: 12, c: 58, f: 6, emoji: '🌅' },
  { id: 2, name: 'Salmon poke bowl', cal: 540, p: 38, c: 52, f: 21, emoji: '🌞' },
];

/** The entry the script "logs"; macros are scripted so the coach reply stays coherent. */
const LOGGED_ENTRY: FoodEntry = {
  id: 3,
  name: FOOD_TEXT,
  cal: 330,
  p: 62,
  c: 0,
  f: 7,
  emoji: '🍎',
};

export const INITIAL_STATE: DemoState = {
  activeNav: 'home',
  foodInput: '',
  coachInput: '',
  focused: null,
  entries: SEEDED_ENTRIES,
  consumed: 860,
  question: null,
  reply: '',
  replyDone: false,
  thinking: false,
  phase: 'playing',
};

/** Resting frame shown when the animation can't run (reduced motion / small screens). */
export const FINAL_STATE: DemoState = {
  ...INITIAL_STATE,
  activeNav: 'food',
  entries: [...SEEDED_ENTRIES, LOGGED_ENTRY],
  consumed: INITIAL_STATE.consumed + LOGGED_ENTRY.cal,
  question: COACH_QUESTION,
  reply: COACH_REPLY,
  replyDone: true,
};

export function demoReducer(state: DemoState, event: DemoEvent): DemoState {
  switch (event.type) {
    case 'input':
      return event.field === 'food'
        ? { ...state, foodInput: event.value }
        : { ...state, coachInput: event.value };
    case 'focus':
      return { ...state, focused: event.field };
    case 'openLog':
      return { ...state, activeNav: 'food' };
    case 'addFood':
      return {
        ...state,
        entries: [...state.entries, LOGGED_ENTRY],
        consumed: state.consumed + LOGGED_ENTRY.cal,
        foodInput: '',
        focused: null,
      };
    case 'askCoach':
      return {
        ...state,
        question: state.coachInput,
        coachInput: '',
        focused: null,
        thinking: true,
      };
    case 'appendReply':
      return { ...state, thinking: false, reply: state.reply + event.chunk };
    case 'replyDone':
      return { ...state, replyDone: true };
    case 'setPhase':
      return { ...state, phase: event.phase };
    case 'reset':
      return INITIAL_STATE;
  }
}
