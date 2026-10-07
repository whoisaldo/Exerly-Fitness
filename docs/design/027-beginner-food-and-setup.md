# Beginner food logging and setup

Ali's 2026-10-07 feedback makes ease of use the next priority. Keep the current
purple and pink identity. Reduce decisions and explain the next action.

## Food logging

The diary exposes Scan barcode in one tap. Search food is beside it. Manual
food creation moves behind More food options. The search screen keeps recents
and favorites, so repeating a food still takes three taps. A camera scan of
one matching food opens its portion review automatically. Nothing logs until
the person confirms the portion.

When camera access is denied or unavailable, offer search immediately. Typed
barcode digits are a disclosure for unreadable packages. When a barcode is
missing, search comes first, then nutrition-label recognition, then manual
entry. A typed-code lookup remains reviewable. Do not claim a physical scan
was verified by a simulator journey.

Reference: MacroFactor's public [food logging guide](https://help.macrofactorapp.com/en/articles/215-how-to-log-food-in-macrofactor)
keeps scan and search available within the logging flow. Its [label scanner](https://help.macrofactorapp.com/en/articles/213-label-scanner)
provides a fallback when a barcode is absent. These are interaction references,
not copied layouts or private app inspection.

## First-time setup

Explain what Exerly does before asking for personal details. Each question
needs a visible reason and a clear effect on the review. Keep U.S. defaults,
preserve explicit metric choices, and allow people to enter their own targets.

The first pass uses the current five-stage cloud contract. Add the existing
experience, weekly schedule and equipment fields to the guided flow. Keep
answers through interruptions and let people go back. Ask fewer questions
on legacy-account repair and retain existing logs and accepted targets.

Show Calories as the review's primary number, then macros and the reason for
the estimate. Explain the difference between a starting estimate and measured
progress. Replace outdated web-diary promises with concrete first actions in
the iPhone app. Dietary preferences must not masquerade as a meal plan.

A full training preview uses ProgramGeneration and the person's equipment,
experience, schedule and session length. Logic owns the new persistence/API
contract. The app asks and explains; Core selects exercises and targets.
Use a reviewable proposal and the existing acceptance path. Never silently
replace an existing training program. Watch and heart-rate experiments follow
the primary nutrition and workout flows.

Reference: MacroFactor's public [program inputs](https://help.macrofactorapp.com/en/articles/370-what-information-does-macrofactor-workouts-use-to-generate-my-program)
and [gym setup](https://help.macrofactorapp.com/en/articles/300-set-up-your-gym-profiles).
An improvement claim requires measured task completion and clear outcomes.

## Verification

Check barcode entry from the diary, search fallback, hit/miss, manual and label
cancellation, three-tap repeats, exact U.S. portions and offline persistence.
Capture default light/dark and largest type, with the real fallback messages.
For setup, verify resume at each stage, back navigation, legacy repair,
independent training/nutrition goals, unchanged accepted targets, and exact
answers after completion. Compare the final screens with the public references
and record remaining friction before internal release.
