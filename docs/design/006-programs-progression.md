# M4: programs and progression

Owner: logic agent. Status: ExerlyCore built and measured, 2026-10-06; server and MCP next.

## Problem

Programs, scheduling, deloads and progression are rows P01, P03, P04, P07 and
P08 in `docs/PARITY.md`. The aim is to match what MacroFactor Workouts does,
from its public help centre:

- **A program** is one cycle of days. A day with no exercises is a rest day.
  The cycle repeats 1 to 52 times, and there are up to 14 training days per
  cycle.
- **Each exercise slot** has sets, a rep range, a target RIR and rest. These can
  differ per cycle (periodization).
- **A deload** can be none, the first cycle or the last cycle.
- **Progression** recommends load and reps from logged sets. A set predicts
  reps-to-failure as the rep range's midpoint plus the target RIR, and doing
  better moves targets up. There is no recommendation before the first log.
  "Expand rep range" and "weight match" are options, and a recommendation is
  never punitive.

The help centre gives no deload amounts, no increments and no rule for how
much targets drop. Those are Exerly's own design, below, checked against
simulated lifters like the detectors (design 005).

## Model (ExerlyCore)

A `Program` is a synced document of kind `program`:

- **Identity:** name, icon and colour.
- **Days:** one cycle, in order. Each day has a name and slots; a day with no
  slots is a rest day.
- **Length:** a cycle count from 1 to 52, and the deload placement: none, first
  or last.
- **Lifecycle:** created, activated and archived dates.

A `ProgramSlot` has:

- an exercise and notes;
- an optional superset group;
- a default `SlotTarget`: sets, rep range, target RIR and rest;
- optional per-cycle `SlotTarget`s;
- `expandRepRange` and `weightMatch`.

A session started from a program records a `ProgramRef` (program, day and cycle)
on the `WorkoutSession`. The field is optional, so older sessions and the golden
file are unchanged.

**Schedule.** The next workout is the training day after the last session that
referenced the program, wrapping into the next cycle. The program is complete
after the last cycle. Rest days are shown but never block the next workout:
training on a rest day is the person's choice.

**Deload cycle.** Unless a cycle has its own targets, a deload cycle:

- halves each slot's sets, rounding up, with at least one;
- keeps the rep range;
- adds 2 to the target RIR, up to 5.

The load then follows from progression at that RIR. Volume falls about half and
intensity a little. This matches the common recommendation to cut volume and
keep loads moderate (Bell et al., 2023, a Delphi consensus of coaches:
observational and expert, not an RCT).

## Progression (pure functions)

Inputs:

- the slot's target for this cycle;
- the exercise's earlier working sets (the latest session, with the recent trend
  for context);
- the load increments available for its equipment.

Steps:

1. **Estimate capacity.** Take the e1RM of the latest session's best working
   set, from reps plus logged RIR. A missing RIR counts as the target. Cap any
   rise at 5 % above the best e1RM of the last four sessions, so a lucky or
   mistyped set can't cause a jump.
2. **Ideal load.** The load whose reps-to-failure is the rep range's midpoint
   plus the target RIR.
3. **Round to equipment.** Take the heaviest available load at or below the
   ideal, then the reps that leave the target RIR at that load.
   - If those reps fall outside the range, the next increment is too far.
   - With `expandRepRange`, the reps may go up to two outside the range.
   - Without it, the load moves one increment so the reps fit the range.
4. **One plan for every set.** Before the session, every set of a slot gets
   the same load and reps. Once sets are done, set-by-set adjustment (below)
   takes over.
5. **Never punitive.** A small shortfall (reps-to-failure within 1 of the
   prediction) holds the load. A larger one lowers the load by the e1RM, never
   more than 10 % in one step.

The result names its basis (the set and e1RM it came from) and its reason:
progress, hold, reduce, or first session. Screens show the reason, and the
MCP server can return the same recommendation.

## Set-by-set adjustment and weight match (PARITY P08)

After each working set, `Progression.adjust` plans the slot's remaining sets
from that set:

- Today's e1RM comes from the set's reps, load and RIR (a missing RIR counts
  as the target). With a plan, it stays within the plan's never-punitive
  bounds, 5 % up and 10 % down, so a mistyped load can't move it far.
- Each later set is planned 2 % weaker than the one before, about a rep at a
  working load with a few minutes' rest. This is an assumption, the same one
  the simulator uses, not a measured constant.
- **Weight match on** (the default): the load stays and the reps follow,
  up to the top of the range. Reps forced below it set `outsideRange`.
- **Weight match off:** each set gets the load that leaves the target RIR in
  range, chosen as the plan chooses.
- **Assessment.** A first session has no load to recommend. Its first set is
  the assessment, and the rest get their loads from it.
- The reason compares the set with what the plan predicted for it, fatigue
  included: within a rep to failure is hold, better is progress, worse is
  reduce.

"The same load as last time", when a small shortfall holds the load, is the
session's hardest load (least assistance), at the most reps, among sets with
an estimate. It used to be the set with the best estimate. Once later sets
can be lighter, a generously reported later set sometimes won that, and the
next plan came out too light. The JavaScript port and its golden follow the
same rule.

Simulated (24 lifters, 16 weeks, day noise 2.5 %, RIR reports ±0.7), the
later sets of a slot land nearer the target reserve:

| Later sets             | Mean error | Bias  |
| ---------------------- | ---------- | ----- |
| As planned             | 0.93       | -0.59 |
| Adjusted, weight match | 0.55       | +0.38 |
| Adjusted, free loads   | 0.53       | +0.30 |

The sets after a first session's assessment go from 0.63 to 0.56 (bias +0.56
to +0.38). The rest of that bias is the planner's: reps round down, so a
prescription leaves the target RIR or up to one more. The next session's
plans are unchanged (0.81).

## Keeping a workout's changes (PARITY P06)

Each exercise started from a program keeps its slot's ID, including through a
swap. After the workout, `ProgramChanges` compares what was done with the day
and offers the differences as one proposal, which the person accepts or
declines like any other and can undo.

- A swap takes over its slot.
- A different number of working sets changes the target for that cycle: the
  cycle's own targets if it has them, otherwise the slot's. Sets in a deload
  cycle without its own targets are derived, so they are left alone.
- An exercise added and done becomes a slot after the one before it. Its
  targets come from what was done: the sets, the range of reps, and the
  average RIR.
- A skipped exercise stays, because skipping once isn't removing, and the
  order is kept.

## Checked against simulated lifters

The training simulator (design 005) gains lifters who follow the
recommendations. Each session's true capacity comes from the simulation, and
the reps they actually do follow from that capacity and noise. Scored:

- the RIR error: actual RIR at the recommended load and reps, minus the target;
- how closely recommended loads track true strength over 16 weeks;
- how often a recommendation lands outside the rep range.

The bounds are recorded here and enforced by tests, as in design 005.

## Measured (2026-10-06)

The simulation runs 24 lifters per noise level, each following a three-day
program for 16 weeks:

- six lifts, at 2 RIR on rep ranges from 4–6 to 8–10;
- gains of 0.2, 0.6 or 1.2 % a week;
- strength fading 2 % per set within a session;
- a quarter of the lifters entering pounds.

The error is the actual RIR on each exercise's first prescribed set minus the
target, from that exercise's third session on (2,016 prescriptions per level).
Positive means easier than planned.

| Day-to-day noise, RIR report error | Exerly                                       | Double progression | Oracle (knows today's strength) |
| ---------------------------------- | -------------------------------------------- | ------------------ | ------------------------------- |
| 1.5 %, ±0.5                        | mean 0.61 RIR off, bias +0.37, 81 % within 1 | 1.47, +0.95, 42 %  | 0.36, +0.36, 98 %               |
| 2.5 %, ±0.7                        | 0.81, +0.35, 69 %                            | 1.55, +0.96, 38 %  | 0.36, +0.36, 98 %               |
| 4 %, ±1.0                          | 1.14, +0.34, 54 %                            | 1.76, +1.10, 36 %  | 0.36, +0.36, 98 %               |

- No prescription fell outside its rep range.
- The recommended e1RM tracked true strength within 1.5, 2.2 and 3.3 % at the
  three noise levels.
- The oracle's error is what rounding to equipment leaves. The rest is the
  day's strength, which no plan made beforehand can know.
- The small easy bias comes from rounding loads and reps down.
- Blending the two earlier sessions into the estimate, weighted toward the
  latest, was tried. It lagged progress and raised the bias to +0.6–0.7
  without lowering the error, so the estimate uses the latest session alone.

## Interface

- `Program`, `ProgramDay`, `ProgramSlot`, `SlotTarget`, `DeloadPlacement`,
  `ProgramRef`.
- `ProgramSchedule.next(for:in:)`, and `ProgramSchedule.target(for:cycle:)`,
  which applies the deload.
- `Progression.recommend(_:history:increments:)`, returning a `Recommendation`:
  load, reps, RIR per set, reason and basis.
- `LoadIncrements` for each equipment type, with defaults:
  - barbell: 2.5 kg or 5 lb steps;
  - dumbbell: 2 kg or 5 lb;
  - machine and cable: 5 kg or 10 lb.

  The person can override them.

- `ProgramStore`, a `DocumentHost` for programs, beside the training and agent
  stores.
