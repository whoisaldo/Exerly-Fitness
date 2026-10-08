# Guided workout plans

The first training screen should give a beginner a useful next step. Build my
workout plan asks for a training goal, days per week, experience, time and
available equipment. Saved setup fills frequency, experience and equipment.
Nutrition and training goals remain independent. A manually built workout or
program remains available.

## Use the published generator

The app passes answers and the selected equipment to Core's
`ProgramGeneration.proposal(for:library:gym:)`. The preview decodes the
program inside that exact proposal. It does not generate again on save.
Previewing and cancelling write nothing. Save files and accepts the reviewed
proposal once. Its program remains separate from the active program until
the person chooses Follow program. The existing Suggestions flow provides
the evidence, confidence, reasons to reconsider, audit and undo.

The builder supports the Core contract of 2 through 6 strength days. A saved
goal of 0, 1 or 7 is explained and requires a choice, not silently rounded.
A home bench means a flat bench, never an invented rack or incline bench.
Available equipment is explicit, including bodyweight movements. An existing
gym retains its load inventory and excluded exercises. New equipment
contexts use 45 lb bars and pound plates by default; an explicit metric
choice uses 20 kg and kilogram plates.

## Account and persistence boundaries

The setup request only reads saved preferences. It cannot resend a pending
profile edit. A late response cannot replace answers the person has begun
editing, or write after their account changes. If saved preferences cannot
load, the builder says so and remains usable offline.

The app composition includes GymStore in the sync engine, agent hosts and
account export. This prepares the existing Core gym contract for subsequent
gym editing and progression work. The builder's per-plan equipment choices
do not silently replace the person's active gym.

## Review and verification

The review starts with the plan, frequency and session budget, followed by
readable workout days. Each day opens its exercises and targets. The full
Core summary includes equipment or workload shortfalls. Saving stays within
reach while scrolling. An error keeps the same proposal available for retry.

Tests cover exact preview-to-save identity, cancel, equipment eligibility,
unchanged active program, offline acceptance, relaunch, account isolation,
unavailable storage, export and undo. Capture the native flow in default
light and dark and at the largest Dynamic Type before release. This is the
guided generation portion of P02. It does not certify full program parity,
exercise coaching, or physical-device performance.
