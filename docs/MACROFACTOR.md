# MacroFactor reference and Beyond seeds

Moved unchanged from the 2026-10-06 brief. The MacroFactor sections list what that
app records and shows, from its own export and public material. The Beyond seeds are
starting ideas for exceeding it; check each against a source before relying on it.

## Ground truth: MacroFactor's own export (Oct 2026)

- **Calories & Macros.**
- **Micronutrients (50 columns):**
  - alcohol and caffeine;
  - B vitamins: B1, B2, B3, B5, B6, B12;
  - minerals: calcium, copper, iron, magnesium, manganese, phosphorus, potassium,
    selenium, sodium, zinc;
  - cholesterol and choline;
  - essential amino acids;
  - fats: mono-, poly-, saturated and trans; omega-3 (ALA, DHA, EPA, total); omega-6;
  - fiber, starch, sugars and added sugars;
  - folate;
  - vitamins A, C, D, E and K;
  - water.
- **Body:** Scale Weight (with fat percent), Weight Trend, Expenditure, Steps.
- **Body Metrics:**
  - bust, chest, hips, neck, shoulders and waist;
  - left and right ankle, bicep, calf, forearm, thigh and wrist;
  - visual body-fat assessment.
- **Muscle Groups:** sets and volume for 22 muscles.
- **Exercises:** 1-RM, 3-RM, 10-RM, total volume, best-set volume, heaviest weight, total
  reps, best-set reps, total and best-set duration, total sets.
- **Food library:** Recipes, Custom Foods, Favorites, History.
- **Training Programs** (cycles, deload, colour, icon) and **Workouts** (exercise, notes,
  per-set type, RIR and rest).
- **Day flags and notes:** Fasting, Partial Logging, Micronutrient Goals, Food Log Notes,
  Workout Log Notes.
- **User Profile:** sex, birthday, height, activity level, sessions per week, lifting
  experience, cardio experience, athletic pursuits, prediction style.
- **Nutrition Program Settings:** per-weekday targets, expenditure and expenditure
  calculation mode, one row per program update.
- **Weight Goals:** goal weight, goal rate in % of bodyweight per week, start and end,
  checkpoints, starting and ending scale and trend weight.
- **Workout Settings:**
  - previous reference, propagate changes, RIR tracking;
  - superset auto-scroll, exercise auto-next, keep-alive, workout timer;
  - bodyweight contribution;
  - rest timers: between exercises, between left and right sets, and per compound upper
    and lower;
  - warm-up automation and schemes;
  - expand rep range, weight match, deload, exercise assessment, hide completed sets;
  - sound and vibration.
- **Gym Profiles:** equipment and weights, allowed and disallowed exercises, bumper and
  mixed-unit plates, offset weight.
- **Custom Exercises:** type, trackable metric, laterality, primary and secondary muscles,
  joint actions, resistance and support equipment, bodyweight contribution, range of motion,
  stability, alternative names.

## Seen in MacroFactor

- **Nutrition Overview:** Yesterday, 1 week, 1 month, 3 months, 1 year. Each nutrient has a
  bar against its target, with a target marker and a percentage.
- **Contributors:** each food's share of a nutrient.
- **Nutrient Timing:** calories across the day.
- **Strategy-based targets.**
- **Shortcuts:**
  - "Log by JSON";
  - "Find Recent Food";
  - a today-summary JSON: `consumed` per nutrient, and `remaining` as minimum, target and
    maximum.
- **Apple Health:** writes nutrients, weight and workouts.

## Beyond: seeds

- **Speed:**
  - a repeat food in 3 taps or fewer;
  - a set in one tap, prefilled from last time;
  - meal copy across days;
  - suggestions by time of day;
  - cold launch to logging in under 1 second.
- **On-device intelligence:** barcode and label scanning; photo and text meal logging with
  confirmation.
- **Training intelligence:**
  - RIR-based autoregulated progression;
  - fractional volume per muscle;
  - recovery-aware weekly volume, using sleep, HRV and resting HR from Apple Health;
  - PR detection;
  - plate and warm-up calculators;
  - supersets;
  - rest timer as a Live Activity;
  - a Watch workout app with heart rate.
- **Agent features:**
  - a weekly review with at most three ranked suggestions, each with evidence and a
    falsifier;
  - program generation and adjustment as proposals;
  - stall and plateau diagnosis;
  - deload detection;
  - n=1 experiments.
- **A food database that beats MacroFactor's on coverage and accuracy:** USDA FDC, Open
  Food Facts and FatSecret, with source shown and community or user corrections.
- **Full Apple Health read and write**, widgets, and App Intents covering MacroFactor's
  Shortcuts and more.
- **Migration in:** import MacroFactor's export (every sheet above), Apple Health history,
  and Hevy and Strong exports.
- **A developer platform:** MCP server, OpenAPI, tokens and webhooks, full-fidelity
  JSON/CSV/xlsx export, stable IDs, UTC plus timezone, and idempotent writes. Ali's
  Ascension dashboard will consume it.
