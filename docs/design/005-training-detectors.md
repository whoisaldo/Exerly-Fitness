# M2d: built-in training detectors

Owner: logic agent. Status: built and measured, 2026-10-06.

## Problem

Agents propose and people decide (design 004). The first proposals and
diagnoses Exerly makes on its own come from the training log, with code-computed
evidence and no model in the loop. They have to be right far more often than
they are wrong: a detector that cries wolf teaches people to ignore it.

## Detectors (ExerlyCore, pure functions over `TrainingHistory`)

**Entry errors become correction proposals.** For each completed working set of
a finished session, the detector compares the set with the same exercise's
typical working sets. "Typical" means the median and spread of the effective
loads and reps of the previous sessions, plus the session's own other sets. It
flags:

- **A stray or missing digit in the load**, such as 1000 kg for 100 kg or 10 for 100. The load is about ten times off, and dividing or multiplying by ten puts
  it inside the typical band.
- **Pounds entered as kilograms, or the reverse.** The load is off by a factor
  of about 2.2, and the same number in the other unit is typical.
- **A stray digit in the reps**, such as 55 or 50 for 5. The reps are far above
  what this load has allowed before, and dropping a digit gives a typical count.

Each flag becomes a `Proposal` from the built-in author with:

- the corrected session as `after`;
- evidence from the person's own data: the typical band, n sessions, and a
  metric reference where one applies;
- confidence from how cleanly the correction lands;
- a falsifier such as "You really lifted 1000 kg."

There is at most one proposal per session. It is never made for an exercise
with fewer than three earlier sessions.

**How a set is judged.** The reference is the exercise's working sets in its last
eight earlier sessions (it needs three), plus the session's other working sets.
That lets a first session with three consistent sets be judged too. It is
summarised robustly:

- the lower median load;
- a band of normal loads, from 55 % of the median up to 135 % of the heaviest
  load within 1.8 times the median;
- a typical e1RM;
- the unit this person usually enters for the lift.

Earlier typos left in the log therefore can't stretch "normal". Two sets far
apart can't say which one is right, so they judge nothing.

**Stall diagnosis is evidence, not a proposal.** For each exercise with enough
recent sessions, the detector computes:

- the slope of the best e1RM per session over the window (least squares, kg per
  week) and its standard error;
- the sessions in the window and the mean RIR of the top sets;
- the weekly fractional sets for the target muscles.

A stall is a slope whose upper bound (one standard error up) is under 0.3 % of
the mean e1RM a week. It needs at least six sessions spanning three or more
weeks in an eight-week window. Caveats are attached: n=1, short
window, RIR not recorded, volume changed during the window.

**Deload signal is evidence, not a proposal.** Several exercises lose e1RM at
the same or lower RIR, comparing the last week or two with the earlier baseline.
It is reported with each lift's change, and labelled a signal: fatigue,
sleep, illness and technique changes look alike in the log. Deload proposals
wait for programs (M4).

## Checked against simulated ground truth

A seeded simulator generates training histories:

- people with different progression rates and noise;
- known injected entry errors (stray zero, unit swap, reps typo) at known sets;
- known plateaus and fatigue blocks.

The detectors run on the generated logs and the results are scored:

- entry errors: precision and recall per error type, and false proposals per
  100 clean sessions;
- stalls and deloads: detection rate and false alarms.

The measured rates are recorded below, and tests fail if they regress past the
recorded bounds.

## Measured (2026-10-06)

The simulated population is 40 lifters for tuning and 40 held out, at 48
sessions each. It mixes kilograms and pounds, gains of 0.2 to 3 % a week,
day-to-day noise of 1.5 to 6 %, bodyweights of 60 to 100 kg, plateaus and
fatigue blocks. The detector runs on every session against the log as it stood,
with earlier mistakes left uncorrected.

Entry errors:

| Population                   | False findings      | Load digit     | Unit swap      | Reps digit     | Precision |
| ---------------------------- | ------------------- | -------------- | -------------- | -------------- | --------- |
| Tuning, clean                | 0 in 1,920 sessions |                |                |                |           |
| Tuning, 3 % of sets mistyped | 2 in 1,920 sessions | 188/191 (98 %) | 113/130 (87 %) | 103/104 (99 %) | 99.5 %    |
| Held out, clean              | 0 in 1,920 sessions |                |                |                |           |
| Held out, 5 % mistyped       | 3 in 1,920 sessions | 318/330 (96 %) | 200/235 (85 %) | 167/176 (95 %) | 99.6 %    |

Known misses:

- the first sessions of an exercise, until there are three earlier sessions or
  three consistent sets in the session;
- a wrong unit or an extra digit on a small added load for a bodyweight lift
  (5 kg against 5 lb on a pull-up barely moves the effective load);
- a doubled digit that still gives a plausible rep count (2 → 22 on a light set).

Stalls, per lift at the end of 16 weeks, over 30 lifters for each noise level:

| Day-to-day noise | Plateau found (8 flat weeks) | False stall, gaining 0.6–1.2 % a week | Flagged, gaining 0.2 % a week |
| ---------------- | ---------------------------- | ------------------------------------- | ----------------------------- |
| 1.5 %            | 135/180 (75 %)               | 0/360                                 | 58/180 (32 %)                 |
| 2.5 %            | 110/180 (61 %)               | 2/360 (0.6 %)                         | 65/180 (36 %)                 |
| 4 %              | 74/180 (41 %)                | 0/360                                 | 52/180 (29 %)                 |

A lifter gaining 0.2 % a week is under the 0.3 % ceiling, so calling that a
stall is by design. Noisy logs need longer flat stretches before a stall is
called; a six-week window found 10 to 20 points fewer and raised false stalls
up to 3 %.

Deload signal, at the end of a two-week block with 7 % lower strength, with
false alarms checked weekly from week 5 to week 15 on lifters who never tire:

| Day-to-day noise | Found | False alarms  |
| ---------------- | ----- | ------------- |
| 1.5 %            | 29/30 | 0/330         |
| 2.5 %            | 29/30 | 0/330         |
| 4 %              | 25/30 | 5/330 (1.5 %) |

## Interface

- `EntryErrorDetector.findings(in:history:)`, and
  `proposal(for:history:existing:now:)`, which returns one proposal per session
  and never proposes twice for a session, whatever the person decided.
- `TrainingSignals.trend(of:in:through:days:)`, `stall(of:in:through:)`,
  `stalls(in:through:)` and `deload(in:through:)`.

A `Diagnosis` holds a title, a summary, evidence items (level, caveats, data
refs, metric references) and the numbers behind them, so screens and agents show
the same thing.
