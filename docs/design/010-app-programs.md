# A6: programs and planned workouts

App owner, 2026-10-06. Follow A5's entry checks and observations. This uses the
published ProgramStore, ProgramSchedule, Progression and TrainingStore contracts.
Preserve the original purple/pink theme and manual workout path.

Training opens Programs and shows the active program's next workout when there
is no workout in progress. An active workout always remains the primary action.
The preview shows the cycle, deload status, exercises, sets, reps, load, target
RIR and Core's reason for each recommendation. An absent recommended load asks
the person to choose one. Starting calls startSession(from:bodyweight:timeZone:)
and keeps every set incomplete until the person logs it. Bodyweight is explicit;
never silently use a profile value as a current measurement.

The first builder edits a local draft. It supports a name, cycles, deload
placement, an ordered list of training and rest days, and each day's exercises.
Exercise rows edit sets, rep range, target RIR, rest, set kind and notes. Reuse
the searchable library and locale-aware numeric input. Cycle overrides show
their cycle and can be removed to restore the base target. Expanded rep ranges
explain the two-rep allowance. Save calls Core validation and preserves the
draft on failure. Cancel with changes asks before discarding the draft.

Rest days are shown in the program, but the current Core schedule advances by
finished workouts and skips those days. The screen says "Next workout", without
inventing calendar assignments or a required training date. Progress uses
ProgramSchedule.progress. Completed programs offer a duplicate to start again;
do not erase or relabel past workouts.

The program list separates available and archived programs. Activate, archive,
restore and duplicate call ProgramStore. Explain when activation replaces the
current selection. Editing a program does not rewrite completed sessions. A
session already in progress stays as logged. Changing future program targets
is explicit. Program proposals use the same complete review, evidence, accept,
undo and history screens as workout proposals, with readable program field
labels and full-value fallback for every unfamiliar field.

Composition creates ProgramStore after TrainingStore. Sync and export include
training, programs and agent; AgentStore hosts training and programs. The same
account change, deletion cleanup and offline guarantees apply. Do not add
program-specific network calls to screens.

The published weightMatch field is currently stored but never used in planning.
Omit its control until Core supplies working behavior and tests. Plate loading
and warm-up entry can follow in this milestone only after their contracts pass
app review, including limited/mixed plate inventories and targets below the bar.
The app must not patch the calculator's arithmetic.

Tests first: real stores cover draft save and validation errors, lifecycle,
starting and advancing a plan, offline relaunch/sync, and account isolation.
Presentation tests cover first-session and outside-range explanations, explicit
units, and full program changes in proposal review. UI tests build a synthetic
two-day program with a rest day, edit a cycle override, activate, start and finish
a workout, reopen the next plan, archive/restore and duplicate. Reconnect after
offline edits and verify the server record. Inspect light/dark on small/large
phones at largest text, including all builder forms and confirmation controls.
Run the full suite and device build, then upload the internal milestone build.
