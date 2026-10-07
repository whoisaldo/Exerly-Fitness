# M12: training volume that follows recovery

Owner: logic agent. Status: built and measured, 2026-10-06. PARITY B05, the
Beyond seed "recovery-aware weekly volume, using sleep, HRV and resting HR
from Apple Health".

## Signals

Apple Health supplies each night's sleep, heart rate variability (SDNN, in
milliseconds) and resting heart rate. The app passes recent days to
`RecoveryStatus.assess(_:on:)`; ExerlyCore stores nothing, because Health is
the record.

## Method

For each signal:

- **Baseline.** The 28 days before the last 3. At least 14 values are needed.
  The centre is the median, and the spread is 1.4826 × the median absolute
  deviation, a standard deviation that one odd night can't move.
- **A floor under the spread.** 20 minutes of sleep, 5 % of HRV, or 1.5 bpm,
  so a very regular baseline doesn't turn a small change into a large score.
- **Recent.** The mean of the last 3 days, needing at least 2 of them.
- **Score.** Standard deviations from the baseline, signed so that negative
  is worse: less sleep, lower HRV, higher resting heart rate. Adverse at −1 or
  below.

The day is **strained** when at least two signals are adverse. It is **not
enough data** with fewer than two signals scored. One signal alone is common
noise, and HRV varies a lot from day to day.

## What changes

`WorkoutPlan.lightened()` keeps two thirds of each exercise's working sets
(rounded up) at one more rep in reserve, up to 5. Loads, reps and warm-ups stay.
The app offers it on the planned workout with the reasons ("HRV 41 ms against a
usual 52 ms, resting heart rate 64 bpm against a usual 58 bpm"), and the person
chooses. Nothing changes the program.

## Evidence, and its limits

HRV-guided training has mostly been studied in endurance athletes, using
morning RMSSD rather than Apple Health's overnight SDNN. Adapting training to
it gave small benefits over fixed plans in those studies, and short sleep lowers
strength and endurance performance. That is enough to offer a lighter session,
not to impose one. The person's own baseline matters more than population
norms.

## Checked against simulated people

Two hundred people, 120 days each, seed 11. Each signal had AR(1) day-to-day
noise: HRV about 15 % (persistence 0.5), resting heart rate 2.5 bpm (0.6) and
sleep 0.8 h (0.2). One value in ten was missing. One 5-day strain was placed
between days 60 and 80.

| Strain (SD of HRV / resting HR / sleep) | Quiet days flagged | Strains caught in their 5 days | Mean day caught |
| --------------------------------------- | ------------------ | ------------------------------ | --------------- |
| 1.0 / 1.0 / 0.5                         | 3.4 %              | 61 %                           | 2.9             |
| 1.5 / 1.5 / 0.5                         | 3.3 %              | 83 %                           | 2.7             |
| 2.0 / 2.0 / 1.0                         | 3.2 %              | 95 %                           | 2.3             |
| 1.5 / 0 / 0 (HRV only)                  | 3.7 %              | 40 %                           | 3.0             |

About one workout in thirty would be offered a lighter version without real
strain, and a clear strain is usually caught by its third day. The tests hold
the 1.5 SD row as bounds: under 5 % of quiet days, and over 75 % caught.
