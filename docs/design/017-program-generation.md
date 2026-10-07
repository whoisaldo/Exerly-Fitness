# M9: generating a program, as a proposal

Owner: logic agent. Status: built and checked, 2026-10-06. PARITY P02, and the
Beyond seed "program generation and adjustment as proposals".

The person says how many days a week they train, their goal and experience,
and optionally muscles to emphasise and how long a session can be. ExerlyCore
builds a program from the active gym's equipment. It arrives as a proposal, so
the person reviews it, edits it in the builder, or declines, and nothing
changes until they accept.

## Split

| Days | Split                              |
| ---- | ---------------------------------- |
| 2, 3 | Full body A, B (and C)             |
| 4    | Upper A, Lower A, Upper B, Lower B |
| 5    | Upper, Lower, Push, Pull, Legs     |
| 6    | Push, Pull, Legs, twice            |

Every split trains each muscle on at least two days of the cycle, as the
frequency research suggests (Schoenfeld, Ogborn and Krieger 2016).

## Volume

Weekly fractional sets per muscle, counting a target muscle as 1 set and a
synergist as 0.5, which is how `Volume` counts them:

| Goal        | Beginner | Intermediate | Advanced | Smaller muscles |
| ----------- | -------- | ------------ | -------- | --------------- |
| Hypertrophy | 10       | 14           | 18       | 6 / 8 / 10      |
| Strength    | 8        | 10           | 12       | 4 / 6 / 6       |
| General     | 8        | 10           | 12       | 4 / 6 / 8       |

The larger muscles are chest, lats, mid back, quads, hamstrings, glutes, side
delts, biceps and triceps. The smaller ones are rear delts, calves and abs.
Front delts get enough from pressing, so they have no target of their own.
Emphasised muscles get 30 % more. About 10 or more weekly sets grow more muscle
than fewer (Schoenfeld, Ogborn and Krieger 2017), with returns falling off
beyond about 20.

## Choosing exercises

A first version chose greedily, by how much remaining need each exercise met.
It put three deadlift variants on one day, because hinges credit the most
muscles. Coaches write programs from movement patterns, so Exerly does too.

- **Patterns.** Squat, hinge, single-leg, horizontal, incline and vertical
  push, vertical and horizontal pull, then isolation by muscle: fly, lateral
  raise, rear delt, curl, triceps, leg extension, leg curl, calf raise and
  abs. Each lists its exercises in order of preference: barbell staples
  first, then dumbbell, machine and bodyweight options.
- **Days.** Each split day is a list of patterns. Upper A, for example, is
  horizontal push, vertical pull, vertical push, horizontal pull, lateral
  raise, triceps and curl.
- **Which exercise.** The first one the gym allows that isn't already in the
  day. A pattern's second appearance in the cycle takes its second option, for
  variety, except that a strength program keeps each day's main lift. With
  nothing allowed, a pattern falls back to a related one, such as rows for
  rear delts or push-ups for triceps.
- **Left out.** Pistol squats, handstand push-ups and Nordic curls for
  beginners. Carries, sleds, cleans and neck work aren't in any pattern.
- **Sets.** 3 per exercise, 4 for a strength program's main lift. Then:
  - days over the session cap lose sets from the end;
  - the muscle furthest under target gains a set, isolation work first, up
    to 5 an exercise. If the day is full, a set moves to it from a slot whose
    muscles stay better served;
  - a muscle over 130 % of target gives a set back, or an exercise when it is
    at 2 sets and every muscle it targets stays at target and trained on two
    days without it;
  - a day's main lift keeps at least 3 sets.

## Targets

| Goal        | Main lift        | Other compounds | Isolation         |
| ----------- | ---------------- | --------------- | ----------------- |
| Hypertrophy | 6–10 reps, 2 RIR | 6–10, 2 RIR     | 10–15 reps, 1 RIR |
| Strength    | 3–5 reps, 2 RIR  | 5–8, 2 RIR      | 8–12 reps, 2 RIR  |
| General     | 8–12 reps, 2 RIR | 8–12, 2 RIR     | 10–15 reps, 2 RIR |

Beginners get 6 cycles without a deload. Others get 6 cycles with the last as
a deload.

## Honesty

The result reports each muscle's weekly sets and the muscles it couldn't bring
to at least 80 % of target, such as hamstrings in a bodyweight-only gym or any
muscle when two short sessions can't hold it all. The proposal's summary
names them.

## Checked

Every combination of 2 to 6 days, three goals, three experience levels and
three gyms (full, dumbbells and a bench, bodyweight only) is generated in the
tests:

- every program is valid, and every exercise is one the gym allows;
- no day has more sets than its cap;
- in the full gym, with 4 to 6 days of 90 minutes, every larger muscle gets
  80 % to 150 % of its target, on at least two days. Advanced hypertrophy is
  the exception: 18 weekly sets for every muscle don't fit, and its gaps are
  reported;
- every shortfall is reported.

Measured with 60-minute sessions, the lowest share of target for a larger
muscle in intermediate hypertrophy was 29 % on 2 days, 43 % on 3, 64 % on 4
and 86 % on 5 or 6; the highest was 129 %. A general beginner program reaches
at least 75 % from 3 days. The proposal names every gap.
