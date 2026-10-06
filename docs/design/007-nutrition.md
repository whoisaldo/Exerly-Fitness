# M5: nutrition, weight and expenditure

Owner: logic agent. Status: M5a and M5b built and measured, 2026-10-06.

## Problem

Nutrition is half of MacroFactor and most of its reputation. Exerly has to match
it on:

- calories, macros and the 50 micronutrient columns of MacroFactor's export;
- trend weight and adaptive expenditure;
- targets from a goal and a strategy, per weekday;
- day flags (fasting, partial logging);
- custom foods, recipes, favourites and history.

Then it has to do better on explanation and on agents.

The legacy food logging lives on the server's `/api` routes, with its maths in
`apps/api/lib/nutrition.js`. That maths is an exponential trend and an energy
balance over 28 days. As with training, nutrition moves into ExerlyCore as
synced documents and pure functions, and the app's screens use only ExerlyCore.

## Model (ExerlyCore, synced documents)

- **`Nutrient`**: the catalog.
  - Energy, protein, carbohydrate, fat and fibre.
  - Every micronutrient column in MacroFactor's export (alcohol, caffeine, the B
    vitamins, minerals, cholesterol, choline, essential amino acids, fatty acid
    classes, omega-3 and omega-6, starch, sugars, folate, vitamins A, C, D, E and
    K, water).
  - Each has a unit and, where public, an adult reference value: US FDA daily
    values, with NIH ODS values where the FDA gives none.
- **`saved_food`**: a custom food or a recipe. Not `food`, which the legacy food log
  already uses in the change table.
  - Name, brand, nutrients per 100 g, serving sizes as gram weights, barcode
    and source (custom, recipe, USDA, Open Food Facts, FatSecret).
  - A recipe also has its ingredients and its yield.
- **`food_entry`**: one logged food.
  - Its local date and meal, the time it was logged, a snapshot of the food (so
    later edits to the food don't rewrite history), and the amount in grams
    with the serving it was entered in.
  - Its nutrients are the snapshot scaled by the amount.
- **`nutrition_day`**: a day's status (unlogged, partial, complete or fasting)
  and notes. The expenditure estimate trusts only complete and fasting days.
- **`weight_entry`**: a weigh-in instant, its local date, the weight as entered,
  and an optional body-fat percentage.
- **`nutrition_plan`**: the goal (lose, maintain or gain), the rate in % of
  bodyweight per week, the macro strategy, and the weekday distribution.
  Versions are kept, like MacroFactor's program updates.

## Trend weight and expenditure (pure functions)

The model is a Kalman filter and smoother over two hidden states:

- `W`: a "true" weight, without the day's water and gut contents;
- `E`: expenditure, in logged kilocalories a day.

Each day:

- `W` moves by intake minus `E`, divided by the energy density (7,700 kcal/kg
  by default, with uncertainty);
- `E` drifts as a slow random walk;
- the scale shows `W` plus noise.

Behaviour:

- **Missing intake.** Days without complete logging add variance instead of
  intake.
- **Missing weigh-ins.** They simply aren't observations.
- **Trend weight.** It is the smoothed `W`, with a band, and replaces the
  legacy exponential average.
- **Expenditure.** It is `E`, with a band. It is in the same units as what the
  person logs, so a steady under-logger gets targets that still work, which is
  MacroFactor's insight, built here independently.
- **Starting point.** Expenditure starts from a formula (Mifflin–St Jeor times
  activity) with a wide variance. The data takes over as it accumulates.

**Checked against simulated people** with known truth:

- expenditure that drifts and adapts to dieting;
- water-weight noise that is autocorrelated, not white;
- logging bias and error;
- missed logs and sparse weigh-ins.

Measured:

- expenditure and trend errors against the truth over time;
- how fast the estimate follows a real change;
- the same scores for the legacy estimator.

The rates are recorded here and enforced by tests.

### Measured (2026-10-06)

The simulation runs 30 people per weigh-in frequency, each for 140 days:

- starting weights of 60 to 105 kg and expenditure of 2,000 to 3,080 kcal;
- a 500 kcal diet or a 400 kcal surplus between maintenance phases;
- expenditure falling 22 kcal per kg lost, with adaptive thermogenesis up to
  5 % and a random drift;
- autocorrelated water swings of 0.6 kg;
- true intake varying by 300 kcal a day;
- logging biased 0.85 to 1.0, with 120 kcal of logging noise and 15 % of days
  not complete.

Estimates are real-time: each one sees only the data up to its day, weekly
from day 28. The truth is expenditure in logged units.

| Weigh-ins              | Expenditure error, mean (90th %) | Trend error | ±2 SD band covers the truth | Legacy expenditure | Legacy trend |
| ---------------------- | -------------------------------- | ----------- | --------------------------- | ------------------ | ------------ |
| Daily (90 %)           | 90 kcal (185)                    | 0.22 kg     | 95 %                        | 94 kcal (196)      | 0.33 kg      |
| Every other day (50 %) | 96 kcal (186)                    | 0.24 kg     | 96 %                        | 111 kcal (244)     | 0.54 kg      |
| About weekly (20 %)    | 114 kcal (228)                   | 0.32 kg     | 95 %                        | 154 kcal (288)     | 1.03 kg      |

- Daily intake noise limits any estimator to about 75–90 kcal at a 28-day
  horizon, so with daily weigh-ins the gain over the legacy method is small.
- The gains are in trend weight, in sparse weigh-ins, and in a band that is
  honest about the uncertainty.
- Expenditure drift from 8 to 25 kcal a day and water persistence from 0.6 to
  0.9 changed the mean error by under 5 kcal, so the defaults (15 and 0.8) are
  not fragile.

## Targets and coaching

- **Calorie target.** Expenditure plus the goal rate times bodyweight times the
  energy density, per day. Rates are capped to safe ranges, and nothing goes
  under a floor of 1,200 kcal without an explicit choice.
- **Macros.**
  - Protein follows a strategy in g/kg (1.4, 1.8 or 2.2), against goal weight
    when that is lower.
  - Fat has a floor of 0.6 g/kg and the diet type's share.
  - Carbohydrate takes the rest.
- **Weekday distribution.** Shifts calories between days and keeps the weekly
  total.
- **Weekly check-in.** A built-in proposal that changes the plan's targets. Its
  evidence is the expenditure estimate with its band, the trend change and the
  logging coverage, and it carries a falsifier.

## Food database and import (server)

- **Search.** USDA FoodData Central (public domain) and Open Food Facts (ODbL,
  attributed). FatSecret only if Ali approves its terms. The source is always
  shown. Search and barcode lookup go through `AccountAPI`.
- **Import.** MacroFactor's export (xlsx) is parsed on the server and becomes
  documents that sync. That needs a synthetic export with the real column names
  for tests, and never anyone's real data.

## Sub-milestones

1. **M5a:** the nutrient catalog, foods, entries, days, `NutritionStore` and day
   totals against targets.
2. **M5b:** weigh-ins, trend weight and expenditure, checked against
   simulation.
3. **M5c:** targets, per-weekday distribution and check-in proposals.
4. **M5d:** food search and barcode lookup through `AccountAPI`, recipes and
   history.
5. **M5e:** the MacroFactor import.
