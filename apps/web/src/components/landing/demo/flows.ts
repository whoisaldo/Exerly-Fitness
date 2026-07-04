/** Logical canvas size the demo is authored against; the stage scales it to fit. */
export const CANVAS_W = 720;
export const CANVAS_H = 430;

export type TargetId = 'nav-food' | 'food-input' | 'food-add' | 'coach-input' | 'coach-send';
export type TypedField = 'food' | 'coach';
export type StepAction = 'openLog' | 'focusFood' | 'addFood' | 'focusCoach' | 'askCoach';

export type Step =
  | { type: 'wait'; ms: number }
  | { type: 'moveTo'; target: TargetId }
  | { type: 'click'; target: TargetId; action?: StepAction }
  | { type: 'type'; field: TypedField; text: string }
  | { type: 'stream'; text: string };

export interface Flow {
  id: string;
  steps: Step[];
}

export const FOOD_TEXT = 'Grilled chicken, 200g';
export const COACH_QUESTION = 'Am I on track for protein today?';
export const COACH_REPLY =
  "You're at 112g of your 140g protein target — that chicken did the heavy lifting. " +
  'A Greek yogurt with dinner closes the gap. Calories sit at 1,190 of 2,200, right on pace.';

export const calorieCoachFlow: Flow = {
  id: 'log-and-coach',
  steps: [
    { type: 'wait', ms: 800 },
    { type: 'moveTo', target: 'nav-food' },
    { type: 'click', target: 'nav-food', action: 'openLog' },
    { type: 'wait', ms: 400 },
    { type: 'moveTo', target: 'food-input' },
    { type: 'click', target: 'food-input', action: 'focusFood' },
    { type: 'type', field: 'food', text: FOOD_TEXT },
    { type: 'wait', ms: 350 },
    { type: 'moveTo', target: 'food-add' },
    { type: 'click', target: 'food-add', action: 'addFood' },
    { type: 'wait', ms: 1400 },
    { type: 'moveTo', target: 'coach-input' },
    { type: 'click', target: 'coach-input', action: 'focusCoach' },
    { type: 'type', field: 'coach', text: COACH_QUESTION },
    { type: 'wait', ms: 300 },
    { type: 'moveTo', target: 'coach-send' },
    { type: 'click', target: 'coach-send', action: 'askCoach' },
    { type: 'wait', ms: 600 },
    { type: 'stream', text: COACH_REPLY },
    { type: 'wait', ms: 2000 },
  ],
};
