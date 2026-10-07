# M5f: nutrient goals, overview, timing and goal ETA

Owner: logic agent. Status: built, 2026-10-06. PARITY N06, N28, N29, N31, N32
(completeness; pinning is the app's preference) and S06.

## Goals (N29)

`NutrientGoal` has an optional floor, target and ceiling, which must be in that
order. A plan version's `nutrientGoals` overrides the reference intake for a
nutrient:

- an FDA minimum becomes a floor, a maximum a ceiling, and a typical amount a
  target;
- energy and the three macros always come from that weekday's `DailyTargets`.

A version never changes once in force, so a past day is always judged against
the goals that held that day.

## Overview (N28, N32)

`overview(from:through:)` counts a day when it has entries and isn't marked
partial, or when it's marked fasting (a real zero). Per nutrient it gives:

- the mean daily amount over counted days;
- the days it was observed;
- the goal on the last counted day;
- the share of goal, with each day measured against its own goal;
- completeness: the share of the counted entries whose food reports the
  nutrient. That is the denominator to explain beside a low average.

## Timing (N06, N31)

`log(..., at:)` records when a meal was eaten. `timing(from:through:timeZone:)`
sums energy by local hour. An entry logged on a different day from its own has
no known time; it is counted as untimed instead of being put at the wrong hour.

## Goal ETA (S06)

`NutritionGoal.eta(from:on:)` compounds the weekly rate from the trend weight
to the goal weight. `checkpoints(from:on:weeks:)` gives the expected trend each
week, stopping at the goal.
