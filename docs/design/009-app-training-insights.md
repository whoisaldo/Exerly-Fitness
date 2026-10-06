# A5: entry checks and training observations

App owner, 2026-10-06. Follow A4's completed suggestion review flow. Preserve the
original purple/pink theme, native navigation and manual logging path. Use the
published EntryErrorDetector and TrainingSignals contracts. Core owns every
finding, metric, threshold and proposed mutation.

After finishing a workout, and after sync receives finished workouts, offer
Core's entry-check proposals in Suggestions. Nothing changes automatically.
Core's existing-proposal argument prevents a rejected or undone check from
returning on relaunch. The UI has an explicit Entry checks setting; turning it
off stops new checks and leaves existing decisions inspectable. Checks run
locally and do not send data to an inference service. A failed check cannot
prevent a workout from being saved or synchronised. Expose a retry only where
there is an actual failure, with no invented result or positive reassurance.

Training opens Observations, which displays the Core stall and deload findings
with their summaries and full evidence. These are observations, not a completed
weekly coaching feature. No diagnosis, prescription, or causation claim is
added by the app. Explain that no finding can mean insufficient data. Use the
account's calendar date and time zone for the analysis window. Follow Core's
ordering until it publishes a ranking contract for the weekly review.

Evidence links for an exercise must open its logged sets, dates, units and
workouts, not merely the exercise's description. Reuse the saved-data metric
verification shown in A4. A workout's estimated max and muscle volume must come
from TrainingHistory/TrainingStore, never calculations in SwiftUI. Missing
bodyweight, RIR and missing or deleted source logs remain explicit.

Entry-check evidence currently needs a Core wording correction when its only
reference is other sets in the same workout. Do not expose a claim about zero
previous sessions as if it came from history. Check duplicate proposals across
two devices before automatic filing. Report both to the logic inbox.

Tests first: compose a real in-memory TrainingStore and AgentStore with
synthetic sessions. Verify finishing, import/sync, relaunch, rejection, undo,
disabled checks and write failures. Test account changes while a check is
pending. Do not duplicate Core's detector maths in presentation tests. Drive
the actual UI with a plausible load history and a mistyped set, then inspect
the evidence, reject, relaunch and prove no repeated proposal. Cover the manual
path with checks off. Verify sparse-data, plateau and deload observations,
exercise-to-workout links, and a missing source record. Inspect all four
largest-text appearance/phone-size variants before the internal release.

Programs, plate loading and warm-ups follow their published Core contracts in
the next slice. Do not silently turn an observation into a changed program.
