# M6a: nutrition for agents

Owner: logic agent. Status: read tools built, 2026-10-06.

The MCP server read only training. A person's agent (and Ali's Ascension
dashboard) needs their nutrition too, with the same numbers the phone shows.

## Read tools

- `get_nutrition_day`: one local day's entries, the totals for every
  nutrient logged, the targets of the plan in force that day, what remains,
  and the day's status and notes.
- `get_nutrition_summary`: each day in a range, up to a year. It gives energy
  and protein logged, the energy target, the status, the scale weight, and
  trend weight and expenditure with one standard deviation.

Each rule mirrors `NutritionStore`:

- the plan in force on a date is the latest to start on or before it;
- an entry's nutrients are its food's per-100 g amounts scaled by its grams;
- only complete and fasting days count as known intake;
- the first plan's expenditure basis is the energy balance's prior, as for
  check-ins.

## One estimator, two languages

`apps/api/lib/nutrition/energyBalance.js` ports `EnergyBalance` step for step.
ExerlyCore's `NutritionGoldenTests` write `docs/api/golden/nutrition-v1.json`:
three logs, with daily or sparse weigh-ins, gaps, unlogged days and two
readings on some days. The port matches every estimate to within one part in
a billion. A live test has the phone log food and weigh-ins through
`NutritionStore`, sync them, and read `get_nutrition_summary`. The server's
trend and expenditure equal the phone's own estimate on every day.

## Next

Proposals for nutrition kinds: an agent logs a described or photographed meal
as a `food_entry` proposal that the person confirms. The app has to host
`NutritionStore` in `AgentStore` first.
