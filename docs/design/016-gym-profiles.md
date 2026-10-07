# M8: gym profiles and the weights a gym really has

Owner: logic agent. Status: built, 2026-10-06. PARITY T05 and T06.

Progression rounded every load to a uniform step, such as 2 kg for dumbbells.
Real gyms jump: dumbbells go 30, 32.5, 35, 40, and a cable stack has its own
pins. A recommendation the gym can't load is a recommendation the person has
to redo in their head.

## Data (synced documents)

A `gym_profile` holds:

- a name;
- the equipment the gym has. Bodyweight needs none;
- its barbells, the usual one first;
- its plates, as pairs of any unit, so mixed kg and lb plates work;
- `loads`, the weights some equipment comes in, such as dumbbells, kettlebells,
  or a machine's stack. Equipment without a list uses its usual steps;
- excluded exercises: ones the person can't or won't do there;
- when it was created, last chosen and archived.

The gym being used is the most recently chosen one that isn't archived, as
with programs, so the choice syncs. Profiles merge as whole values.

## What uses it

- **Progression.** `LoadIncrements` gains `available`. When it is set,
  progression chooses among those loads, at most three either side of the
  ideal load, instead of stepping. A barbell's step is twice the gym's
  smallest plate, and its minimum is the gym's usual bar.
  `GymStore.increments(for:)` gives these for the active gym, and the usual
  steps without one.
- **Exercise choice.** `GymProfile.allows(_:)` is true when the exercise isn't
  excluded and the gym has all of its resistance and support equipment.
  Pickers, swaps and program generation use it.
- **Warm-ups and plates.** The gym's bar and plates feed `WarmUpScheme.sets`
  and `Plates.load`.

## Not yet

- An offset weight for machines whose start isn't zero, and bumper plates
  told apart from iron. MacroFactor's export names both; they can follow the
  MacroFactor import, once its headers are known.
- Per-exercise overrides of a gym's loads.
