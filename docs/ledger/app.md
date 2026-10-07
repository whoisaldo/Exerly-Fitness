# App agent ledger (Astra)

Read AGENT_BRIEF.md, this ledger and to-app.md after every reset. Done is not
met. No parity row is fully device-verified. Continue through milestones.
Current date 2026-10-07, updated 19:33 EDT.

## Merge status

Quick add is merged and pushed at ce9c7b21. The exercise-search toolbar fix
passes default light/dark and largest-text gym journeys and is landing next.
A14 candidate 2610072240 remains withheld after its fixed UI failure. Its
other two groups finished successfully, but the candidate is not a release.
A13 build 2610072129 remains live. A15 will combine gyms, Quick add and the
search fix at a new fixed commit. Explicit label portions are in progress.

| App branch                         | Unlanded work                                                                                      | Last landed / cleanup                       |
| ---------------------------------- | -------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| `agent/app`                        | None, git cherry empty                                                                             | Deleted locally/remotely                    |
| `agent/app-next`                   | None, git cherry empty                                                                             | Deleted locally/remotely; worktree removed  |
| `agent/app-programs`               | None                                                                                               | A6 landed 19925b28; branch deleted          |
| `release/app-nutrition-foundation` | None                                                                                               | Foundation landed 60e83cf9; branch deleted  |
| `agent/app-nutrition`              | Exercise-search fix passed; label portions in progress                                             | Quick add landed/pushed ce9c7b21, 19:20 EDT |
| `agent/app-label`                  | None; local commits patch-equivalent, original remote differs only by an already-landed inbox item | Deleted locally and remotely                |
| `release/app-design`               | None; fixed A14 candidate failed its UI gate                                                       | Fixed 181eac03; candidate 2610072240        |

## Search toolbar corrected, 2026-10-07 19:33 EDT

The same largest-phone gym journey now passes in 269.850 seconds. Default
SE light passes in 198.751 seconds with all 205 active hosted tests and one
credential skip. Largest text passes in 519.243 seconds, and all seven final attachments
were inspected. Close stays visible and the inventory headings wrap cleanly. The device build and changed-file SwiftLint pass.
The fix keeps Close visible during active exercise search on iOS 17.1+.
The regression explicitly requires the button to be visible and tappable.
The default light/dark captures, eight and seven attachments, were inspected.

A14 group 1 passed all 15 methods. Group 2 completed all 25 declared methods,
including its expected context skips. Group 3 is an interrupted failure and
must not count as a full pass. A fresh A15 full gate will run all 61 methods
from a fixed source with Quick add included. Integration remains open.

Label portions are the next slice, separate from the staged search fix.
Three new hosted tests pass with the complete 208 active hosted suite, one
credential skip. Initial native light/dark journeys pass; their six captures
were reviewed. Review found that the current nutrient summary sits too low
and the label weight is overprecise. Fix that hierarchy and display before
landing; stored weights must remain exact. No portion release claim yet.

## Quick add ready; A14 navigation failure, 2026-10-07 19:17 EDT

Final Quick add journeys pass in default light, default dark and largest text:
147.123, 143.007 and 363.461 seconds. All four captures from each final run
were inspected. The final device build passes, all 205 active hosted tests
pass with one credential skip, and changed nutrition files pass SwiftLint.
Core 308 and API 261 passed at the unchanged domain/API source. N05 is Built,
not device-verified. Calories and macros can be logged with no food weight,
then corrected after offline relaunch. Missing and zero remain distinct.

Comparison contact-review/a15-quick-reference.png places final light/dark
screens beside MacroFactor's public Quick Add and App Store images and the
old manual-food editor. The four-field entry removes the old food/weight
setup. MacroFactor is denser and offers macro-derived Calories and several
quick items per plate. Those capabilities remain explicit follow-ups. The
selected meal now appears in both the header and the Log to meal action.

A14 group 1 completed successfully. Group 2 continues. Group 3 was stopped
after testGymInventorySavesMixedUnitsOfflineFiltersExercisesAndRestoresArchivedPlaces
failed to find Close during active exercise search on the largest phone.
The screenshot a14-gym-failure.png confirms the sheet remains visible while
its navigation toolbar is hidden. Its search-dismiss icon is at the bottom.
The run ended with code 73 after interruption; no passing claim. A14
2610072240 is retained as a failed candidate and will not upload. Fix the
search toolbar in primary, land it, then cut a new fixed release candidate.

## Quick add visual correction, 2026-10-07 18:56 EDT

All five first light attachments and four dark captures were inspected.
The small phone showed the selected meal below the initial fold. The header
and persistent action now name the meal, such as Log to Lunch. Intro copy is
shorter. The public reference is references/macrofactor-quick-add.png from
MacroFactor's Quick Add guide. Its macro-derived Calorie estimate and plate
integration remain explicit follow-ups; no estimate is added in app code.

The subsequent dark journey and existing unweighed regression pass, together
with all 205 active hosted tests. The device build passes. The old AX capture
was interrupted after the destination-label change. A replacement started
before cleanup finished and was also stopped. Both attempts ended with code
73 and are preserved with no passing claim. Both processes have exited.
Final default light then AX now run sequentially on 39; final dark runs on EBE.
Do not touch either simulator until its run finishes. A14's fixed simulators
and source remain independent.

## A14 fixed and Quick add in progress, 2026-10-07 18:49 EDT

181eac03 is merged and pushed to integration and the app branch. The release
worktree is fixed, tracked-clean and building A14 2610072240. Archive and
exported IPA pass identity, signature, HealthKit, Apple sign-in, debug-marker,
privacy and internal-only checks. The full gate selects all 60 UI methods once.
Release simulators 7D, 02 and 718 are reserved until those runs finish.

Quick add uses the published Core contract. Four focused presentation tests
pass, including whole-portion persistence, unknown versus zero, macro-only
values, locale parsing, invalid input, changed account and repeated save.
The first light and dark native journeys pass, with cancellation, offline
logging, relaunch, correction and exact synchronized export. The light run
also passes all 205 active hosted tests. All four dark captures were inspected;
the light export is ready for inspection. Nav title is the compact Quick add.

The remaining copy now says Whole portion instead of Unweighed portion.
Final dark runs all hosted tests, the quick journey and existing unweighed
regression. Final AX runs the quick journey on 39. EBE runs dark. The device
build is running. Review those captures and land this nutrition slice next,
without changing A14's source. No physical checks or full parity claimed.

## Gym inventory ready to land, 2026-10-07 18:39 EDT

The final largest-text gym journey passes in 522.041 seconds. All seven new
captures were inspected: inventory headings now wrap at spaces, with the
count below. The final light journey passes in 190.248 seconds and all 201
active hosted tests pass, one credential skip. All eight light attachments
and 16 primary/empty AX captures were inspected. The latter two opt-in tests
pass in 47.347 and 67.060 seconds. Dark gym, manual-program and guided-plan
regressions already pass. Core 308, API 261 and the final device build pass.

SwiftLint is clean for the changed components and new gym code. Its first
invocation omitted DEVELOPER_DIR and failed to load SourceKit; retry with the
required Xcode 26.2 environment passes. This was a tool setup failure.

The gallery includes the gym captures at http://100.80.149.7:39215. The public
comparison is contact-review/a14-gym-reference.png. T05/T06 are Partial, with
remaining feature/device gaps recorded. A14 notes are ready. Land this slice,
then fix the release worktree at that commit for the full 60-method gate.
Quick-add model/view, four presentation tests and design 030 are drafted but
not registered in the project or part of this gym commit. Continue them after
cutting the release. Main remains a982be2d; the Logic inbox requests its merge.

## Gym accessibility correction, 2026-10-07 18:31 EDT

The gym's largest-text journey passed in 506.477 seconds. All seven captures
were inspected, exposing a real layout issue despite the pass: the inventory
heading broke a word because the count occupied the same row. ExSectionHeading
now stacks its detail under the title at accessibility sizes. Default sizes
retain the horizontal layout. The current-gym explanation now says equipment
settings to avoid implying exact finite plate combinations.

A fresh largest-text gym run and default-light hosted/gym regression run are
underway. The device build passes. The first primary AX capture invocation
skipped both opt-in methods because its capture flag was missing; it provides
no capture evidence. A corrected capture invocation is running on EBE. No
simulator test claims VoiceOver or physical-device verification. The visual
comparison a14-gym-reference.png has been generated and inspected.

## A13 available and gym visual review, 2026-10-07 18:28 EDT

A13 build 2610072129 uploaded at 18:18 EDT. Apple now reports VALID and
IN_BETA_TESTING. Final verification confirms one tester, only this build, and
exact en-US notes. A12 was detached after the new build became available.
The pushed source tag is ios/internal-2610072129 at 208ed075. Notes describe
workouts per week, not calendar scheduling. Metadata evidence is in the
release tree at artifacts/nutrition/a13-internal-2610072129.json.

The fixed gate covers all 59 declared UI methods once: 50 pass and nine
context skips. All 197 active hosted tests pass, with one credential skip.
Core 308, API 261 and the signed device/archive checks pass. Final selected
setup and beginner captures were also inspected: a13-beginner-light has 14,
a13-setup-dark has seven. No physical-device verification is claimed.

Gym light passes all 201 active hosted tests, the gym journey and manual
program lifecycle. Dark passes the gym and guided-plan journeys. The final
device build passes. All 15 light and 15 dark captures were inspected,
including regression screens. The current gym now appears once; available
weights share a compact inventory; lb is the default and saved kg remains kg.
MacroFactor's equipment reference offers denser summaries and presets.
Exerly now keeps its first actions visible and its inventory compact. Icons,
presets and per-workout overrides remain explicit parity gaps.

The first largest-text attempt failed because the test queried a lazy result
before scrolling it into view. The rerun reveals the result first and has
passed that step. It is still completing archive/restore and export. The red
attempt remains preserved. Finish this run and inspect its captures, then
land the gym slice promptly and cut A14 from its fixed commit.

## A13 visual review and gym corrections, 2026-10-07 18:09 EDT

Fixed A13 group 1 passes all 15 UI methods. The added default-light primary
and empty-state capture also passes. All 23 selected group-1 dark captures
and all 16 default-light captures were inspected. Folders are a13-primary-dark
and a13-primary-light. The original E/pulse identity, visible Scan action,
summary-first diary, clear empty-training action and readable U.S. values hold
on SE and the larger phone. The public comparisons recorded for A13 remain
a13-barcode-reference.png and a13-workout-reference.png. MacroFactor still
shows more choices at once; Exerly keeps the first logging actions visible.
The gallery is updated and returns HTTP 200 at http://100.80.149.7:39215.
The other fixed groups continue with no failures. No A13 upload yet.

Gym verification exposed two test-helper issues. A native search field lives
in the navigation bar and must not be scrolled below it. Checking its element
type before existence then broke lazy off-screen controls such as Undo; the
existence guard now comes first. These red/interrupted results are retained.
The second light gym attempt also failed to turn off a gym filter reliably
while searching. The UI now offers explicit At this gym and All exercises
choices and dismisses the keyboard on search submission. The test checks the
selected state, and leaves search before closing the library. Fresh matrix:
gym-chips-light/dark/ax. The light group includes all 201 active hosted tests
and manual program lifecycle; dark includes guided plan regression.

Current gym renders once, mixed-unit weights share a compact inventory card,
and required weight entry now says Enter weight instead of Unknown. Planned
workouts name the current gym, allow changing it, and flag unavailable
exercises without silently changing the saved program. Core still supplies
every load recommendation. The updated device build passes.

## Gym checks and fixed A13, 2026-10-07 17:55 EDT

Core 308, API 261 and the gym device build pass. The SE run now passes all
201 active hosted tests with one credential skip. Its gym journey continues.
The EBE hosted attempt never launched a test host. Diagnostics stopped at
PID 0 and wait_for_debugger, so it was interrupted and only that owned
simulator was shut down and rebooted. No release simulator or service changed.
The EBE attempt has no passing-test claim and failed to finalize its log.

The second gym journey saved mixed units offline and restored the current gym
after relaunch. It then exposed the shared reveal helper treating a visible
navigation-bar search field as scroll content. That interrupted run's four
captures were exported and all reviewed. The current-gym repetition and roomy
weight cards visible there are already removed. The helper now recognizes a
visible search field and prioritizes keyboard Done over sheet Done. A fresh
light run includes all hosted tests and the whole gym journey.

A13's fixed gate has 34 active UI methods passed so far and no test failures;
remaining methods continue. A default-light primary/empty-screen capture on
EBE is running from fixed 208ed075 in the release tree. Reserve that simulator
until a13-primary-light finishes, then use it for final gym dark captures.
The main release sims remain 7D, 02 and 718.

## Gym inventory in progress, 2026-10-07 17:51 EDT

The primary branch and integration both pushed 208ed075. The first own-branch
push failed only because the working ledger was unformatted; formatting and
retry passed the hooks. A13's signed archive and exported IPA pass source,
identity, signature, privacy, HealthKit, Apple sign-in and internal-only checks.
The fixed 59-method UI gate continues with no test failure seen so far.

New primary source adds named gyms, explicit Use, archive/restore, mixed-unit
inventories, filtered exercise selection, and active-gym workout recommendations.
Four hosted gym tests pass, including 32 kg standard versus an available
32.5 kg dumbbell, offline reopen without conversion, stale edits and sign-out.
The full hosted run, native journey, Core/API suites and device build continue.
Nothing from this gym slice is landed or released yet.

First compile fixes were a nonexistent surface token, the keyboard helper's
argument label, and registering the test source in the compact PBX test list.
The first native attempt exposed a keyboard-dismissal problem on SE. Its
screenshot is artifacts/programs/gym-first-live.png. That attempt was interrupted
with SIGINT after capture; it is not a passing run. The name now has a keyboard
action and dismisses on scroll/return. The helper prioritizes the numeric
keypad's Done over a sheet's Done. The second native journey continues.

Reviewed the public MacroFactor gym/weight screens. The initial Exerly design
repeated the current gym and gave every weight a separate large card. Current
gym now appears once and weights share a compact inventory card. Final captures
still need review in default light/dark and largest text. New app source has
no SwiftLint warning; existing Core-owned warnings remain outside this slice.

Next: finish the native journey, run the final appearance matrix and all hosted
checks, review captures, land a passing gym slice and retain A13's fixed source
until its upload gate completes. The EBE full hosted run is taking unusually
long to launch, so check its log before claiming it passed.

## Fixed A13 running, 2026-10-07 17:29 EDT

208ed075 is fast-forwarded and pushed to integration. The release worktree
is fixed there and its tracked tree is clean. Its scripts are
artifacts/nutrition/run-a13-verified-1/2/3.sh. They select all 59 UI methods
exactly once; group 2 also runs every hosted test. Separate simulator and
fixture pairs are 7D/39225, 02/39222 and 718/39226. Do not use those in the
primary tree until their release runs finish. Primary 39/39224 and EBE/39228
remain available. Build 2610072129 is archiving; upload waits for the gate.
The staging health endpoint reports PostgreSQL connected and API 2.0.0.

Continue app work from primary while release verification runs. The next
useful workout slice is named gyms and actual available weights, using the
published GymStore contract. Connect that inventory to Core progression so
recommendations fit the gym. Keep U.S. defaults and exact saved mass. Do not
change the fixed release source or interrupt its simulators.

## Guided workout plan ready, 2026-10-07 17:28 EDT

The final native plan journey passes in light, 158.658 seconds, dark,
119.811 seconds, and largest dark type, 414.728 seconds. It uses saved setup,
reviews a complete day, cancels without writing, saves another exact preview
offline, relaunches, undoes it and checks the synchronized export. All 24
final UI captures plus the hosted synthetic label were inspected. The manual
program lifecycle also passes. Final hosted coverage is 197 active tests
plus one credential skip. Core 308, API 261 and the final device build pass.

Review found one offline edge case: an active local gym was ignored until
preferences loaded. The builder now seeds local equipment immediately and
still fills frequency and experience when preferences arrive. The extended
four-test plan suite passes with this case and verifies the read uses GET.
A save error remains beside Save plan, preserving the exact reviewed UUID.

The largest-type preview had a redundant eyebrow and long action labels.
Removing that eyebrow and using Save plan and Build plan makes the title,
summary and actions fit better. Equipment checks no longer consume a large
part of the row. The final captures are plan-setup-final-light/dark/ax.
The reference comparison is contact-review/a13-workout-reference.png.
MacroFactor's public screen shows more training days at once and uses a
calendar. Exerly explains its rotating cycle and gives each day a direct
review link, so it does not imply calendar scheduling that does not exist.
The first-use instructions remain visible to explain starting weights and
reps in reserve. Exercise demonstrations and advanced program options remain
open parity work, not claims of this release.

P02 is now Partial. This slice builds, reviews, accepts and undoes a real
Core-generated program; split/deload choices and physical-device verification
remain. Release notes are prepared in docs/release/a13-internal-notes.txt.
The fixed A13 UI manifest covers all 59 methods once, with no omissions or
duplicates. Its run starts after this landing. Continue the remaining food
and workout work while that fixed release verifies; do not hold integration.

## Setup ready to land, 2026-10-07 17:16 EDT

The final setup passes in light, 304.791 seconds, dark, 215.134 seconds, and
largest dark type, 668.903 seconds. All 13 light captures, 30 combined dark
captures and 13 AX captures were inspected. The corrected AX journey selects
More carbs and verifies low_fat on the server after completion. Its exact
training question, measurements and chosen units survive relaunch.

Core 308 and API 261 pass. The combined hosted suite passes 197 active tests
plus one credential skip, and the device build passes. The setup slice adds
two hosted tests; the other four belong to the forthcoming plan slice.
The manual program lifecycle still passes, 140.430 seconds. The guided-plan
AX journey also finished successfully; inspect its captures before landing.

The public comparison at contact-review/a13-barcode-reference.png shows the
logging entry point beside MacroFactor's public App Store screenshot. Exerly
now exposes scanning from the diary, and unavailable-camera fallback starts
with search. MacroFactor's screenshot still fits more food choices on screen.
No physical scan or speed superiority is claimed. Named-serving defaults are
still a follow-up with Logic. The new setup review puts Calories and macros
before expandable explanations and keeps Finish visible at large type. One
iOS 26 capture caught a changing progress label and disclosure chevron; the
capture helper now waits for those setup transitions as it already does for
primary design captures. The fixed release run will recapture them.

## Beginner setup and workout builder, 2026-10-07 17:06 EDT

Barcode-first logging landed as 30bc0aed and integration is pushed. The
setup slice is staged separately. Do not add the full UI-test file to that
commit: its guided-workout method belongs to the following training slice.

Default light and dark signup preserve appearance after relaunch and pass.
All 29 captures from each beginner-review-light/dark run were reviewed.
The AX rerun reached the correct training question after restoration, then
exposed a test-helper error: a partially visible More carbs choice was tapped
through the fixed Continue button. The captured review still said Balanced.
The helper now excludes all fixed setup and plan actions when scrolling and
checks that More carbs is selected. The red result remains in
beginner-ax-restored.xcresult. Fresh tests are beginner-ax-footer and
beginner-footer-light/dark.

The review also required too much scrolling at largest type. Finish setup
now stays visible, the target explanation expands on request, and training
preferences sit below the Calorie and macro summary. The default appearance
checks are being repeated for this final layout. The goal selection no
longer forces a spring animation when Reduce Motion is enabled.

The first guided-plan journey passes in default light, 165.377 seconds, and
default dark, 127.599 seconds. It loads four days, intermediate experience,
dumbbells and a flat bench from saved setup; previews without writing; saves
offline; relaunches; undoes the accepted proposal; then verifies the server
export. All eight light captures were reviewed. The proposed plan has one
summary, readable days and a persistent Save action. The manual lifecycle
and largest-type plan checks continue. Four new hosted tests pass within the
197 active hosted suite, with one credential skip. The device build passes.
This is app presentation over Core's published generator, not app-side
exercise selection. GymStore is included in account sync and export.

Next: finish setup and plan capture checks, land each passing piece, then
cut the next internal release from a fixed commit. Keep integration moving.
P02 still needs advanced program work and physical-device verification.

## Final beginner review, 2026-10-07 16:37 EDT

A12's fixed full gate passes all 49 active UI methods with nine context skips.
Build 2610072011 uploaded successfully and Apple reports VALID. The tag is
pushed. Group assignment and exact notes passed at 16:37 EDT: one Ali tester, only
this build, IN_BETA_TESTING. The first final read was not yet consistent; the
subsequent verification passed. A11 was detached only after A12 was available.

The first beginner matrix passes 193 active hosted tests plus one credential
skip, six light UI journeys, four dark UI journeys and three AX-started
journeys. All 97 UI captures and the synthetic label attachment were inspected.
The screenshot review revealed that signup cleared every launch argument on
relaunch, removing both light appearance and largest type. The later setup
captures are therefore default dark, not evidence of largest-type setup.
The test now removes only the session-reset flag. Fresh appearance-preserving
setup, primary and barcode journeys run as beginner-review-light/dark/ax.

Visual fixes from the review: diary logging actions now stack when their full
labels cannot fit; a found barcode visibly offers Review portion or Add to
meal, and Search becomes secondary. The target-weight field uses the shared
surface. These are being captured again before landing. Training generation
remains the next milestone, using the published Core proposal contract.

## Beginner flow implementation, 2026-10-07 16:22 EDT

N04 is merged and pushed as 7f6ccf9e. Three redundant owned stashes were
backed up to artifacts/nutrition/n04-retained-stash-*.patch, then dropped.
The fixed A12 full gate has passed group 1, including Health permission in
52.514 seconds. Groups 2 and 3 continue without test failures. Signed build
2610072011 is archived and exported. Archive and IPA identity, signature,
HealthKit, Apple sign-in, privacy and internal-only checks pass. Upload waits
for the remaining full gate; A11 remains the live Ali-only build.

The primary tree now has a one-tap diary scanner, adjacent Search food,
secondary manual barcode digits, and a More food options menu for label and
manual creation. Camera matches open the portion review automatically. Meal
selection can also scan and add a food to its unsaved draft. The light meal
cancellation journey passes 222.554 seconds with this path and confirms that
no diary entry was written. Physical camera use is still unverified.

The new setup presents eight questions over the existing five cloud stages.
Training experience, weekly workouts, equipment and macro style now reach the
existing request, rather than silently keeping defaults. The local checkpoint
also restores the precise question inside the week stage. A cloud draft from
another device resumes at the start of that stage with its answers retained.
New profiles use Other/prefer not to say for gender, not an assumed male
identity. Explicit metric and manual targets stay intact. The final review
explains target inputs and gives first-day actions. It does not claim that a
meal plan or generated workout has been created. ProgramGeneration UI and
cross-device training-setup extensions remain next.

Core 308, API 261, 193 active hosted tests plus one credential skip and device
build pass. Legacy repair passes 24.115 seconds. Default setup reached the
diary and restored the exact training question after relaunch. Its original
run stopped later at the barcode disclosure's propagated accessibility ID.
That ID is now on its own button. The corrected direct scanner/search/hit/miss
and three-tap repeat journey passes 149.808 seconds. Original red/interrupted
runs remain. The native toolbar menu also replaced a custom hit area; menu
rows are tapped directly instead of scrolling and dismissing the open menu.

All six first barcode captures and ten setup UI captures were reviewed at
contact-review/barcode-first-light-01/02 and beginner-setup-first-dark-01
through -04. The setup's old black target-weight field still looked like a
stock input; it now uses the shared input surface and number style. The final
three appearance/text-size runs are in beginner-final-light/dark/ax. Capture
and review their results, then commit in passing pieces. A later training
milestone must turn the saved answers into a Core-generated, reviewable plan.

## Ali's usability direction; N04 ready, 2026-10-07 15:46 EDT

Ali accepts the improved visual direction but finds the app hard to use. Next
priorities are beginner-friendly food logging and guided first-time setup.
Barcode first, search second, manual entry last. Explain the app, ask useful
questions, and make the answers shape training and nutrition. Watch and heart
rate are secondary and experimental; food and workouts come first. Do not
resume quick-add or recipes ahead of these usability changes.

N04's final combined gate passes: Core 308, API 261, device build, 191 active
hosted tests plus one credential skip. Default light's primary capture and two
meal journeys pass in 351.000 seconds; default dark in 502.220 seconds. Both
largest-text meal journeys pass in 641.716 seconds. All 47 exported captures
were reviewed, including default-size primary screens in both appearances.
The public MacroFactor comparison is contact-review/a12-meal-reference.png.
Exerly's earlier instruction card gave foods too little room. The compact
header fixes that; whole-gram secondary labels, fully visible meal chips and
Added checks address Logic's critique. MacroFactor still exposes scanning
faster. Ali's next milestone directly addresses that gap.

Main CI a982be2d remains failed. Its Health video shows Opening Health access
with no native permission sheet. A fresh Exerly App iPhone 16 Pro simulator
on iOS 18.6 passes the same journey in 45.276 seconds, including read-only
permission, relaunch and disabling access. CI used iOS 18.5. This is evidence
of a CI-specific failure, not proof that the CI problem is fixed. Preserve
both results and verify Health again in the fixed full release gate.

## A11 shipped; N04 combined gate, 2026-10-07 15:30 EDT

A11 build 2610071910 is VALID and IN_BETA_TESTING. One Ali tester, one assigned
build and exact English notes are verified in the release evidence. A10 was
detached only after A11 became available. Signed archive and exported IPA pass
all release checks. No physical-camera or pure-French-label claim is made.

Unweighed-entry journeys passed default dark 111.455s, small light 98.630s and
largest dark 268.723s. Captures were inspected. They keep the entry scope and
whole portion explicit; largest type uses one nutrient column. A11's full gate
retains the original missing-label-fixture failure and its passing seeded
rerun. Final test evidence records the original and follow-up results.

N04 is rebased onto 6a2ec460. Combined Core 308, API 261, 191 active hosted tests
plus one credential skip and device build pass. Light/dark primary and both
meal journeys are running. Largest cancellation passed 267.882s. The earlier
footer fix passed the entire offline journey in 403.557s. No app data error was
found. The compact selection header now leaves more room for foods, following
the public MacroFactor comparison in contact-review/a12-meal-reference.png.
Invalid zero portions now give one instruction instead of two equivalent Core
messages. All stored precision remains unchanged.

Main's CI run 37643561510 at a982be2d failed Health permission, leaving the app
waiting for Apple's authorization sheet. The artifact is being downloaded for
inspection; this is not called a passing CI run. Search ranking now passes.

## Unweighed entries and final meal verification, 2026-10-07 15:07 EDT

Integration advanced before N15 could fast-forward. Rebased scanner source
onto 236fc88c and reviewed the new quick-add contract. Unweighed entries now
hide weight and portion controls, retain their whole-portion nutrients when
edited, and stay out of the food library. Full 185 active hosted tests plus
one credential skip, Core 308, API 261 and device build pass on this source.
The offline unweighed UI journey passed in 111.455 seconds, including relaunch
and exact export. N05 creation UI is still open.

The previous largest-text meal offline run failed because the test dragged
through the fixed Add foods button while scrolling. Its original red result
and video remain in plate-largest-dark-final. The helper now keeps gestures
above that button; a focused rerun is in progress. Final light critique checks
passed, including all hosted tests and both meal journeys. Fresh capture review
and final dark captures follow. No failed run has been erased or called green.

## N15 ready to land, 2026-10-07 11:35 EDT

Final source includes a982be2d. Both reported basis regressions pass. All nine
label tests pass, including actual Vision on US and bilingual Canadian images.
Full184active hosted plus1credential skip, Core307, API260 and device build pass.
Affected UI reruns pass: camera/manual80.355s, photo225.890s, search135.676s.
The fixed full UI gate already covered all46active methods plus9context skips,
with the missing-fixture photo rerun recorded separately. No known test failure
remains in the scanner candidate. Original failing results are retained.

Default light/dark primary screens and scanner light/dark/largest-type review
were compared with public references and reviewed. A11 internal notes are ready
in docs/release/a11-internal-notes.txt. Land the scanner, cut its fixed source,
archive and upload, verify Ali-only delivery, then continue N04. Do not publish
privacy drafts or submit to App Review. N04 is still only in the primary tree.

## Final meal polish and label correction, 2026-10-07 11:28 EDT

N04 both journeys pass default light, default dark and largest dark. Exact
weights and unknowns pass export. The final invalid-portion check originally
looked for an Other accessibility element; the actual combined error is a
StaticText. Generic identifier lookup passes, and the capture confirms the
visible message. Full181active hosted and device build pass after the error
focus/selection/meal-row changes. UI reruns of that polish continue.

Logic's four screen-review points are applied: whole grams only in the meal
review, full-width meal chips, no second Search toolbar action when selecting
foods, and muted short unknown-value marks. Exact stored weights are unchanged.
Selection now shows Added with a check and keeps that state when reopened.
The decorative plus is hidden at largest type to give the food name more room.
These last visual adjustments still need fresh captures and verification.

N15 all46active UI methods passed on fixed4d3ad510 across the three groups plus
one seeded photo rerun;9context-specific methods skipped. Extracted failure
video confirms the original Photos grid had only simulator landscape pictures.
The original result remains red. N15 is rebased to17f31458 over d0b8a602;
Core307/API260/device/full184active hosted and the three affected UI journeys
are running in the release worktree. The title/per100g regression failed on
d104a53e; a982be2d corrects it. Canadian bilingual actual-Vision test passes.
Keep the app's English-label wording; no pure-French claim.

## Integration and design review, 2026-10-07 11:10 EDT

Rebased primary onto d104a53e. Reviewed both new Logic commits. Core307,
API260, full181active hosted plus1credential skip, and device build pass.
The search test now uses Synthetic oat, passed99.142s on the small phone.
That one-line CI correction is landed as a small separate piece.

N04 cancel/edit journey passes128.680s. The first failure was duplicate food
identifiers across sheets, fixed with distinct selection-mode IDs. The second
failure was a summary identifier propagating to three nutrient accessibility
nodes; it now belongs to the visible heading. The offline test reruns on39.
Both journeys also run in default dark on02 and largest dark on7D.
Original failing results are retained. No data assertion has failed so far.

N15 fixed4d3ad510 full gate groups1and2 pass. Group3 has one label-photo
failure because718 selected a preexisting non-label image, with no label seed.
All its other tests pass. A seeded rerun now runs on718; keep the original red.
The failure exporter contained no failure screenshot, so do not claim visual
inspection of that failure. The existing default/light/dark/AX scanner journeys
already pass on the other simulators.

All20 fresh N15 primary light/dark captures reviewed, plus scanner default
dark sheets1-3 and latest AX sheets1-2. Review and fallback copy are readable;
AX macros use one column. The side-by-side a11-label-reference.png compares
light/dark review with MacroFactor's public App Store food picker. Exerly gives
OCR uncertainty and the original photo more space, needed before saving. Its
plain food picker still requires more steps than MacroFactor for multiple
foods; N04 is addressing that gap. Core title-vs-explicit-basis review is
requested in both Logic inboxes before scanner release. English-only wording
stays until bilingual Vision checks pass; no claim of pure French support.

## N04 meal builder and N15 gate, 2026-10-07 10:53 EDT

N04 implementation is in the primary app-nutrition tree from45417cd4, separate
from the held label feature. Design026 records the flow. Six hosted model tests
pass, including storage failure, repeated confirmation, exact named portions,
metric volume, stale row edits and unknown values. A disposable in-memory Core
NutritionStore computes and validates the preview; only final Log meal writes
through the account store's atomic plate API. The initial compile failed for a
missing loggedAt argument in the new test, fixed before any simulator test ran.

The two new UI journeys run on39B20FBF with fixture39224. Other simulators are
reserved for N15: group1 is7D2096B8/39225; group2 is02A671D3/39222; group3 is
7189880A/39226. Do not assume group numbering maps to a different simulator.
The first plate compile targeted718 but never installed or ran because of that
compile error. The corrected run uses39 only.

N15 group3's label test failed because718 did not have the synthetic label photo
seeded. Its other tests continue. Keep the original red result, inspect its
failure capture, seed the known label after the group finishes, then rerun only
that journey from fixed4d3ad510. Other groups continue independently. The real
Core basis failure still blocks release, regardless of these UI results.

Logic has b0fe2e6c limiting generic matches to a quarter of search results and
requests a deterministic packaged-food search in our CI test. Read that inbox
item from Logic's current worktree, since the primary to-app copy is older.
Apply the small test fix separately, then review/rebase after it lands.

## N15 release held for Core basis correction, 2026-10-07 10:29 EDT

A10 remains live. N15's default iOS26 photo journey passes222.380s, camera
fallback81.865s. Small default light passes153.467s/60.511s and latest AX
passes349.766s/129.861s. The native Photos center tap fixes the iOS26 remote
accessibility hit-point issue. Original red runs are preserved. Latest AX
captures confirm complete Calories and carbohydrate headings in one column.

Final contract review found a real P1: NutritionLabel.read treats any kJ as
per100g even when the label explicitly says per serving. A50g/200kcal bar is
saved as200kcal/100g instead of400. The new hosted regression proves both
failures in label-kilojoule-basis.xcresult. Core correction is requested in
both Logic inboxes, with the exact reproducer. N15 must not ship or land while
this fails. No app-side arithmetic workaround.

Keep N15 source in agent/app-label and its UI validation in the existing release
worktree. Continue independent N04 plates from landed45417cd4 on
agent/app-nutrition. Rejoin the label feature after Logic corrects the contract.

## A10 shipped; N15 full checks, 2026-10-07 10:22 EDT

Build2610071410 is VALID and IN_BETA_TESTING. Exact English notes, one tester
and one assigned build verified in release artifacts/nutrition/a10-internal-
2610071410.json. Previous1223 detached only after1410 was available. Apple build
and delivery UUID4b0598ef-61f7-469b-96c7-1f76ac5724b5. Do not archive or upload
this build again. Fixed source79d4c213. Continue N15 and then multi-food plates.

N15 Core305, API260, device build and all181 active hosted tests plus one
credential skip pass. Default small light photo/manual journeys pass60.511s
and153.467s. Current AX rerun covers the widened nutrient fields; dark rerun
uses a verified visible-center tap for the iOS26 Photos accessibility issue.
Full UI release gate remains pending. Scanner images stay transient and on
this device; saved custom food nutrients sync normally.

## A10 release review, 2026-10-07 10:17 EDT

Signed build2610071410 passed archive/export checks and is uploading from fixed
79d4c213. All20 primary light/dark captures were reviewed in eight contact
sheets, then the diary, training, library and progress were compared with the
public App Store references. The new portion controls were compared separately
in contact-review/a10-portions-reference.png. Selected presets now have a check,
the unit name precedes the amount, and estimated density appears beside the
control. Calories and the unknown macro state remain distinct below it.

MacroFactor's logger fits more foods on one screen. Multi-food staging remains
our next speed improvement; the single-food editor now gives its portion and
meal choices clear priority. The primary summaries, small type, row alignment
and original purple/pink identity remain consistent across light and dark. No
new visual release blocker found. Gallery196 namedviews on port39215.

N15 AX review found Calories and carbohydrate headings split across two narrow
columns. The food editor now uses one column at accessibility sizes and a
focused rerun is in progress. Choosing another photo now cancels an earlier
recognition request before opening the picker. iOS26 photo-grid automation still
reports a visible thumbnail as not hittable after its privacy banner closes.
The helper will tap the verified visible center, still using the actual Photos
picker and Vision pipeline. Original red runs remain in artifacts/nutrition.

## A10 landed, N15 verification, 2026-10-07 10:10 EDT

U.S. portions passed the full fixed66575ac6 release gate: 175 active hosted
tests plus one credential skip, 44 active UI journeys plus nine opt-in skips.
All53 UI methods were assigned exactly once. After rebasing onto f900ef64,
Core305, API260, device build, all175 hosted tests and both affected planned
workout/program journeys passed again. App and UI sources were unchanged by
the rebase. Landed source0b5e74e9, release source79d4c213. Manifest and logs are
in the release worktree artifacts/nutrition/a10-verified-*.

Reviewed Logic's f900ef64 progression contract. Set-by-set adoption remains
open in the app; the Core change alone is not a P08 UI claim. N03 also marks
selected presets, addressing the earlier program-control critique.

N15 runs Vision on a resized local image, groups visual rows, and sends the
recognized text to Core's NutritionLabel parser. The image stays in memory.
All six model tests pass, including real recognition of aligned label columns,
unknown versus zero, per-100ml weight, cancellation, invalid images and stale
results. Default-light photo/cancel/manual journeys pass. Latest large-type
small-phone journeys pass117.641s and341.837s. The iOS26 default-dark photo
journey failed in the system photo picker after it could not tap a thumbnail;
its fallback journey passed77.267s. Investigate and rerun, retain the failed
result. No OCR release claim yet. A10 has no OCR code.

## A9 shipped, A10 full gate, 2026-10-07 08:53 EDT

A9 upload succeeded at 08:44:29. Apple build and delivery ID
7cd73165-a84a-4ce1-bab7-bea743058e94. Internal availability, exact English notes,
Ali-only membership and the single assigned build are verified in release
artifacts/nutrition/a9-internal-2610071223.json. Previous1054 detached only after
1223 was IN_BETA_TESTING. Release notes state the entry correction and scrolling
changes, and do not claim food units or OCR are included.

Fresh primary light/dark journeys pass and every exported primary capture was
inspected. New correction default light/dark and largest-type captures were
compared with the public MacroFactor logger. The correction screen gives more
space to the whole-portion scope than that logger, which is necessary to prevent
a library-wide interpretation. Common fields lead; less-used nutrients collapse.
Large text keeps complete field labels and moves them onto separate rows. The
reference has greater food-entry density; multi-add remains a feature backlog
item, not a claim in this release. Original PNGs and comparisons remain on disk.

N03 default-light and both largest-type journeys pass, as do 175 active hosted
tests, Core301, API260 and device build. The draft itself now also defaults to
pounds if no preference is supplied; existing explicit portions stay unchanged.
All53 UI methods are assigned exactly once across three fixed66575ac6 groups.
Group1 reruns the hosted suite after that default change. Full gate is pending.
N15 uses the already published Core label parser with native image capture and
Vision; no Core/API changes. Keep completing milestones after this one.

## N03 units implemented, testing, 2026-10-07 08:37 EDT

New controls cover ounces, grams, U.S. fluid ounces, milliliters and named
servings. Every entry route receives the account preference. Existing explicit
measures persist. An exact portion anchor prevents display rounding from changing
stored weight, and invalid input blocks switching without clearing the draft.
Volumes use only the recorded density; assumed weight is labeled beside the input.
Shared presets now mark their current value, addressing Logic's program critique.

All 23 nutrition presentation tests pass. Both new default-light journeys pass,
including offline save, relaunch, reconnection and exported exact weights. The
ounce flow also passes at largest type on the SE in 188.223 seconds. Fresh fluid
AX verification runs on 39B20FBF/39224 after restarting that simulator.

The original combined AX run is not a pass. It first expected eight displayed
decimal places where NutritionNumberField intentionally shows three. The test
now expects the display value while independently asserting exact exported
weight. Its second test stalled in XCTest animation-idle waits during sign-in;
it was interrupted, fully torn down, and rerun separately. No app animation was
changed to hide that harness failure. Preserve those original logs.

A9's full passing results are in the release worktree's
artifacts/nutrition/a9-verified-manifest.json. The signed archive and IPA are in
apps/ios/build/release/2610071223. Finish A9 upload before cutting the N03 release.
N15 label capture is planned, not implemented. Continue without ending here.

## A9 entry correction source ready, 2026-10-07 07:51 EDT

The complete correction journey passes at default light238.174s, default dark
235.517s and largest text on the SE444.388s. The focused scrolling regression
passes55.915s on the SE and also passes on iOS26, including cancellation without
any changed meal or portion. The fix is a simultaneous tap recognizer on ExScreen;
borderless buttons alone did not fix it. The original failing center drags stay
in the regression. No test gesture was diverted around the controls.

Core300, API260,171 active hosted tests and the current device build pass. The
first two suites were rerun after the new models; subsequent changes are the
shared scroll gesture, stacked date labels and test selectors. All51 UI methods
are prepared exactly once across three fixed-release groups, with the complete
hosted suite in group1. Run that gate before landing and uploading A9. Current
TestFlight remains1.0(2610071054), not this new feature.

Default light review: clear whole-portion summary, Calories and macros above the
collapsed nutrient groups, unknown values visibly separate from zero. The public
MacroFactor logger reference is denser, but this correction screen needs the
scope explanation so a label edit cannot be mistaken for a library-wide change.
Largest type revealed squeezed date labels, now stacked above their pickers.
Capture exports remain in artifacts/design/nutrition-correction-*.

Next independent work is N15 native label capture, planned in design025 using
Logic's existing NutritionLabel contract. N03 inverse serving conversion is
still pending in both Logic inboxes. Continue without ending at the release.

## Entry corrections in progress, 2026-10-07 07:26 EDT

Update07:39: default-light correction journey passes238.174s after fixing empty
placeholder matching and distinct Cancel selectors. Core300/API260 pass again.
The AX issue is a real interaction bug, not nutrient arithmetic: a focused test
starts at150g and two center drags select50g. Before/after captures are exported
to artifacts/design/nutrition-scroll-diagnostic. A borderless button style still
fails. The shared ExScreen is now testing an empty simultaneous TapGesture to
restore touch cancellation. This matches reports at
https://developer.apple.com/forums/thread/763436. Do not bypass the regression
by dragging around controls. v3 AX has the original bug and is red; v2 AX was
interrupted by the prior runner's teardown and has no valid test result. The
current gesture experiment runs on7D2096B8 with fixture39225. Dark default runs
on7189880A with fixture39226. New large-text date labels stack above their pickers.

N08 uses FoodEntry.editingNutrients through a staged editor. Whole-portion
Calories and nutrients can be corrected without changing the library or source.
Blank remains unknown, zero remains measured zero. Parent cancellation discards
corrections. Four hosted tests cover precision, stale drafts and snapshots.
The complete hosted suite passes171 active tests with one credential skip;
device build and scoped lint pass. No Core/API edits.

UI runs entry-correction-light and entry-correction-ax are red and unfinished.
One harness error treated the empty-field placeholder as entered text; its fix
is in the working tree. Both runs select a hidden Cancel in stacked sheets.
The AX run also shows99.5 Calories for a seeded150g portion that should show
149.25. Investigate whether scrolling changes the portion before changing any
expected value. Do not claim this feature verified, merged or shipped yet.
Logs and screenshots are in artifacts/nutrition. Continue debugging and land
the passing piece promptly, then resume food units and multi-food logging.

## Design release shipped, 2026-10-07 07:04 EDT

Version1.0 build2610071054 is live in internal TestFlight. Apple build and delivery
ID2369b3ca-bb37-40f7-b0c0-b83831fa2d40. Exact English notes verified, only Ali and
only the new build assigned, IN_BETA_TESTING.0024 was detached after1054 became
available. Release evidence: release worktree artifacts/design/design-internal-
2610071054.json and apps/ios/build/release/2610071054. Source5e351cc8. Obsolete
0818/0937/1041/1049 were never uploaded. Do not restart design validation or
archive1054 again. All finished code is landed. Continue new nutrition work.

Next: N08 entry nutrient corrections using FoodEntry.editingNutrients, with
snapshot/source/library preservation, unknown values and stale-draft guards.
N03 food units needs Serving.quantity(grams:) or equivalent, requested from Logic
in both inbox copies. Implement independent published contracts while awaiting
it. Then multi-food plates, quick entries, recipes and account CSV/import.

## Final release source, 2026-10-07 06:54 EDT

Default program builder363.938s and lifecycle111.573s pass with the new choices.
The full small-phone AX agent flow passes228.218s, empty44.550s, secondary134.555s.
The focused AX offline/export/reconnect128.914s passes and its five images confirm
Saved account uses whole words and Export stays reachable. Fresh default primary
light60.334s and dark61.207s pass. All eight updated before/after/reference sheets
were reviewed. Summary hierarchy, grouped numbers, food rows and next actions
retain the original identity. Differences from the references now concern the
remaining feature backlog rather than an unstructured settings-first layout.

Two final image corrections hide decorative symbols at AX only: Connect an agent
no longer splits Connect, and navigation rows give Barcode its full width. The
Connect check passes65.806s, and the navigation check also passes; review its
export before upload. Default layouts and every action/accessible name stay the
same. This is the last app delta beyond the full baseline, with affected checks
rather than another unrelated full-suite restart.

Staging login succeeds. Live banana, salmon and ground beef searches return USDA
foods first, exact household portions, and the proper attribution. The read-only
response evidence is artifacts/design/staging-generic-search.json. Core's inverse
serving conversion remains requested in both Logic inbox copies; while awaiting
it after release, entry nutrient corrections and other published nutrition
contracts are independent work.

## Full design suite passed, 2026-10-07 06:42 EDT

All three fixed5b2c9f92 release groups passed. Exactly49 UI methods were partitioned
once:40 active passes and nine documented opt-in/cross-client skips. Hosted tests:
167 active passes and one private-credential skip. The real iOS reminder banner
arrived, captured in release-verified-1. Core300/API260, device build and all push
hooks pass. Group1 has65 captures, group2 has54, group3 has60. They are exported
into the primary gallery at http://100.80.149.7:39215.

The AX program choice sheet completed the full offline, relaunch and workout
advancement journey in578.789s. Reviewed all13 captures in five contact sheets.
The sheet keeps all three Deload choices readable and marks the selection.
Correcting the draft removes the former validation error. Saved account wrapped
as ac-count in the offline header at the largest size;8e1488c2 hides only its
decorative icon at accessibility sizes, freeing text width. Device build/lint pass;
a focused offline AX capture remains. The default program-control journeys and
agent AX recheck are finishing. Fresh default large light/dark primary captures
both pass and are exporting. Do not rerun unchanged full suites for these deltas.

Reviewed final small dark sheets6/13/14/19/20 and large dark sheets4/11/13/20.
Workout volume is grouped to4,189lb·reps, program errors sit beside the corrective
action, proposals show2→3 RIR before source links, and the real notification uses
the original pulse icon. Weight entry is above its separate reading date, export
uses the native share sheet, and20.5fl oz survives relaunch. These current captures
confirm the previously recorded hierarchy and precision fixes. Food amount units
and richer nutrition workflows are still the next milestone, not shipped claims.

Current internal TestFlight remains2610070024 until Apple confirms the new build.
Archive2610071041 is fixed at8e1488c2. Signed0818 and0937 are obsolete and were never
uploaded. Release notes describe the design changes and U.S. defaults, with the
physical-device and remaining feature limits. After internal availability, resume
nutrition; never end at the upload.

## Final release verification, 2026-10-07 06:21 EDT

Current internal build remains2610070024. Do not upload the obsolete signed
2610070818 or2610070937. The latter passed signing checks but missed the final
keyboard and program corrections. After current verification, fix the release
worktree to the latest passing app commit, archive a new timestamp and upload.
Do not stop after internal availability. Resume nutrition with food ounces and
fluid ounces first, then entry nutrient corrections, plates, quick entries,
recipes and account CSV/import.

Completed after rebasing onto71604c45: Core300, API260,167 active hosted tests
plus one credential skip, device build and push hooks. The private TestFlight
account also signs in successfully against staging, without printing credentials.
fe86's final-design-complete groups1 and3 passed13 and14 UI methods; group2 was
stopped at the wrapping agent name keyboard defect. Its replacement passed the
agent journey133.125s, account81.830s and activity/sleep299.543s before it was
superseded by the complete5b2 run. Preserve these distinctions in release notes.

The keyboard-program-final-ax run proved the Return fix, then failed because
the test checked the now-offscreen empty state without scrolling. Added that
scroll in45a36cd5. Its empty, photo import/relaunch and secondary captures passed.
All current weight controls are visible before the reading date; the former
blank date region is gone. Export now exposes its action before the explanatory
text. Shortened weight and food-brand placeholders that truncated at AX.

The same AX run found the program Deload menu did not open when tapped. A wider
hit area alone did not fix it, so dff64429 gives program choices an explicit
selection sheet at AX sizes, with a checkmark, full-width buttons and cancel.
Default sizes keep compact menus. The new program-choice-sheet-ax run has
successfully opened and selected No deload cycle and reached validation; the
rest of the program journey continues. Device build and scoped lint pass.
Once green, check its default-size program flows too. Other screens are
unchanged by this private control; don't repeat unrelated tests without cause.

RootView's cached-account notice now says Saved account. The old Offline label
could remain while both record stores were synced. Retry still checks auth.
No Core/auth behavior changed. Both cached-account UI assertions were updated.
Reviewed USDA71604c45 and corrected privacy drafts: the search uses a local USDA
table plus Open Food Facts for the same query, with at most200 cached OFF query
results in memory, reused for five minutes. Sent that wording correction to Logic.

Active verification commands and logs: release artifacts/design/run-release-
verified-{1,2,3}.sh and release-verified-manifest.json, fixed5b2c9f92. Primary
artifacts/design/run-program-choice-sheet-ax.sh uses the fourth SE simulator.
Fixtures39222/24/26 were restarted from71604c45 API source;39225 matches it too.
Use primary artifacts/design/design-test-progress.py for progress. The full suite
is independent of primary changes, and integration is free for Logic to land.
New screenshots are in the gallery, but failed program/menu captures are excluded
from the after selection and kept in their raw result bundles.

## Complete review suite passed; final corrections, 2026-10-07 05:39 EDT

05:50 update: signed 2610070937 passes archive checks but is superseded, not
uploaded. Reviewing default program images found a validation message that
stayed after correcting the draft. Clear prior errors on edits and assert the
corrected message disappears. The largest-type agent journey exposed Return
inserting a newline into the new wrapping name field rather than dismissing
the keyboard. c1456da0 treats that Return as Done while preserving wrapping.
Stopped only the failing AX run, retained its red bundle, and will rerun the
affected flows. The fixed fe86 full suite continues independently, with 167
active hosted tests passing and one credential skip. New USDA API work landed
71604c45; its review and corrected cache privacy text are in to-logic.

All critique-complete groups pass at0a15b7fe:166 active hosted plus one credential
skip,40 active UI plus nine optional/cross-client skips. API256 and Core299 pass;
device build and branch push hooks pass. The new U.S. water test passes90.618s
and verifies607ml stored after20.5fl oz offline/relaunch/reconnection. Hosted
stale-offline regression passes1.584s. Small light default native audit passes
41.861s; program builder365.779s and proposal111.070s pass. Small dark AX's five
flows all pass, including account export134.453s and agent connection199.318s.

37 AX captures inspected in13 contact sheets. Found actions displaced by copy
in export/connections/empty states, a truncated agent name, and a blank date
region before weight input. Fixed these in001d5a8d. Actions precede explanatory
copy at AX, the name wraps, and the weight input precedes a separate compact
date card. These are final design corrections, not new nutrition features.
Native default tests still use0a sources until refreshed; don't call those new
layout images. The gallery includes both sources and keeps originals.

Logic2edab7c8 resets sync state on account changes and purge; its hosted
regression is adopted in fe86bec0. Staging API now matchesf7b92d41, including
food validation. No legacy Health reader/authorization callers remain in app;
Logic will remove the old Core methods after this branch lands.

Fixed fe86bec0 now runs final-design-complete-{1,2,3} with49UI methods exactly
once and every hosted test in group1. Restarted the three isolated fixtures to
this source. Primary runs final-actions-small-dark-ax with account, connections,
empty/secondary screens and real synthetic photo import. New signed archive is
preparing; build number lives in release artifacts/design/final-design-build.txt.
Do not upload0818 or call the new archive available before Apple confirms it.
Current TestFlight remains2610070024. Keep going after the design upload.

Stopped nine unused app fixture servers after checking PID/command/cwd. Kept
39222/24/25/26 and the39215 gallery; no protected services changed. Primary plus
one release worktree remains. Own branch was pushed92180e55 with checks passing;
the latest rebase will need force-with-lease again. Initial failed critique
compile bundles remain marked red, superseded by the passing full runs.

## Final critique implemented, 2026-10-07 05:07 EDT

Health fixed4186 completed all three groups:165 active hosted,39 active UI,
nine optional UI skips and one credential skip. Signed archive2610070818 is
superseded and must not upload. Currentfixed0a15b7fe adds Logic0580 sync/food
contracts, CoreHealth nullable reads, final volume and the last visual critique.
All49 UI methods are partitioned once in critique-complete-manifest.json in
release artifacts/design, with every hosted test in group1. API/Core rerun in
primary, device compilation already passed the revised layouts before the
small Health nullable adoption. The initial critique builds failed on an
incorrect SetKind name; corrected to standard and decomposed the large view.
Those red build bundles are retained, not reported as UI results.

Changes: compact default-size set table with a stacked accessibility layout;
inline program choices, validation beside days with VoiceOver focus, opaque
program toolbar; grouped before/after proposal values above program links;
clear agent name field and filled confirming action; one export route which
selects local data offline and states omissions. Sync combines both stores and
shows the older successful time. Logic has the account-reset timestamp finding.
Measured zero Health values now differ from no visible samples, with coverage.
Shared numeric placeholders use zero; absent nutritional values remain unknown.

Logic’s privacy review is incorporated: native food search has no Exerly search
cache, legacy barcode caching is separate, cloud web coach error records and
webhooks disclosed in the draft. Public legal/hosting choices remain for Ali.
Evidence labels use Personal report and Your logged data without claiming that
an anecdote is the user’s or that personal data means exactly one workout.

Old branches remain reconciled and deleted. git cherry reports Health code
patches from4186 equivalent; its only unmatched ledger commit is superseded by
this more recent ledger. The named combined-sync stash was committed then
removed. Own app branch needs a force-with-lease push after the two rebases.
Next: inspect refreshed light/dark/AX captures, land passing pieces, cut a fresh
signed internal TestFlight build, then resume nutrition with the new Core food
units, entry corrections and recipe contracts. Do not end at this milestone.

## Final Health candidate and comparison, 2026-10-07 04:29 EDT

Primary/release fix 4186a492 for the Health delta. Internal archive2610070818
and IPA pass signed release checks, but are not uploaded. Complete 48-method
suite runs as health-complete-{1,2,3}; 165 active hosted plus the real Health
permission journey already pass. Groups 2/3 continue. Integration remains87.
Native Health permission/relaunch passed separately44.522s, with two read types
and no write types. iOS26 light full accessibility audit passes62.570s; large
light/dark AX and default captures pass. Small AX photo import passes again.
The repaired largest-type program builder passes596.150s, not the earlier red
bundle. Its Target3RIR query is disambiguated and Start planned is scrolled back
into view. Source/captures are retained in program-ax-repaired.

Reviewed eight final before/after/reference sheets. One remaining display defect,
4188.783lb·reps in the last-workout summary, is corrected to a whole grouped
total, with no stored-data rounding. Singular working set is corrected too.
These two formatting lines are outside4186 and need the final release to include
them. Do not upload0818 while this newer design correction is outstanding.
Logic has resumed and is implementing the stale-sync fix and requested food-unit
helpers. Wait for the published commit, then apply the named sync stash, keeping
one copy of the hosted regression if Logic lands it. Do not edit Core.

## U.S. and accessibility batch landed, 2026-10-07 04:14 EDT

87abfb67 is merged and pushed. All 47 UI methods ran exactly once across three
isolated groups, 38 active passes and nine opt-in/cross-client skips. All 162
active hosted tests pass, one credential smoke skip. Device build and push
hooks pass. Evidence is release artifacts/design/refined-complete-{1,2,3} and
the manifest. Core/API are unchanged from their 295/250 passing runs.

Health permission changes are committed cb6c9c92. The complete hosted suite now
passes 165 active tests, including three Health permission/account-isolation
regressions. Device and scoped lint pass. Small dark largest-type capture found
the repeated Apple Health title and long introduction displaced the switch.
Removed that repetition, shortened the copy and moved the switch above it.
Default/AX captures and the real native permission flow are being checked.
Photo comparison is labeled Compare photos because AX stacks the images.

The outstanding combined-sync change and its two regressions are preserved in
stash `Pending Logic fix: combined sync status and failing reconnect regressions`.
They are not in integration or the release candidate. The P1 remains in Logic's
inbox. The known Core bug must be fixed before that change lands, but it need
not prevent shipping the independently passing design work. Logic already
supplied a design critique; its six findings have been addressed. A further
review of final captures remains requested, not a new approval requirement.

A read-only comparison confirms staging's deployed API JS/SQL/package files
match the current checkout exactly, with a healthy database. No restart needed.
Gallery has 164 named views, original references, before captures and refreshed
AX sources. N08 is Partial: quantity/time/meal edits and undo work, but per-entry
nutrition override is not yet built. Resume nutrition after the design upload.

## Refined candidate and remaining findings, 2026-10-07 03:55 EDT

87abfb67 commits U.S. water, exact Core conversions, adopted target plans,
Calories left, empty-day zero logged versus unknown nutrients, shared keypad,
cycle presets and consistent confirmation sheets. The fixed release worktree
runs all 47 UI methods once in three groups, plus all hosted tests and device
build. Integration stays open. Original b7 batch remains landed and pushed.

Small-phone final default light/dark captures and full native accessibility
checks pass. There are 162 active hosted passes plus one skip before the new
Core regression. A native iOS 26 contrast failure with no returned element
was isolated using an unhandled diagnostic audit. Apple's element screenshot
identified the selected Body segment. Purple fill/white text now passes the
exact contrast audit in 17.280s. The general diagnostic switch remains opt-in.
No audit element or failure is ignored. Largest-type final captures continue.

Ten deep contact sheets, 30 captures, reviewed program editing/targets/overrides,
planned sessions, lifecycle confirmations, source estimates, agent diffs/evidence/
audit and tokens. Compared with Workouts and Things, a truncated program intro,
duplicate activity-history chevron, and small stock confirmation buttons still
looked unfinished. Fixed all three. Refreshed sheets use landed sources and
retain original images. Earlier A6/A4 deep captures are copied as before evidence.

Primary's combined Account Sync UI exposes a real old Core defect: successful
pulls retain the preceding error/offline flags. Water/manual food/program/agent
uploads and edits succeed, but final Account synced assertions fail. A hosted
regression reproduces both stale flags in 1.938s. Logic has the exact test and
request at 03:40. This sync change and regression remain outside the fixed
candidate. Do not claim the combined screen is ready.

The first new smallest-phone AX program run hit an ambiguous Target 3 RIR label
in virtualized rows, then cascaded. Interrupted that obsolete run after retaining
evidence. The test now selects the first matching target and explicitly returns
to Start planned workout. It must be rerun before claiming that AX journey green.
Current source captures and real photo import are running on SE light at largest
type. No new nutrition features until the design TestFlight release.

Health settings review found unsupported sleep/workout success marks and an
unneeded workout write-permission request. The app-owned permission layer now
requests only steps/active energy, scopes opt-in by account and environment,
keeps missing/denied reads as unavailable, and rejects late permission results
after dismissal. Three hosted regressions and the device build are pending.
No Core source edited. Final Logic critique and its sync fix remain release gates.

## Design batch landed, 2026-10-07 03:22 EDT

The fixed b7b082b7 candidate passed every active test: 160 hosted, 38 UI,
with one hosted and eight opt-in/cross-client UI skips. The manifest partitions
all 46 UI methods exactly once. Program builder passes 330.549s, lifecycle
124.216s, and signup recovery 233.002s. Core 295, API 250 and the device build
pass. Fast-forwarded integration and pushed successfully, including hooks.
Logic should advance main. Accessibility refinements and the final U.S. group
continue in primary without holding integration.

The iOS 26 large-dark native audit now passes 54.984s after macro targets and
Today received complete accessible names. Small light/dark already pass.
Refreshed screenshot review found the empty diary's dashes still read as
missing data. Display Core's zero logged intake only where no entries omit
the nutrient. Missing label values remain unknown. Hosted coverage checks both.
Remaining generic numeric fields now use the shared keypad; program cycles
use presets and a stepper, avoiding a shared focus binding with the name field.
These final changes are under verification. The stale legacy sync state still
needs Logic's Core fix, and the final independent visual critique is pending.

## Passing accessibility and fixed integration candidate, 2026-10-07 03:08 EDT

Committed b7b082b7 for verified/retried test input and 5dc7ae91 for accessible
controls, readable placeholders, shared button contrast, compact Progress
navigation, and rounded weight entry that preserves the exact saved value.
Primary retains one U.S./target/sync group in progress. Release now fixes
b7b082b7 after git cherry confirmed all original 67ed9442 patches are present.
The previous full 67ed9442 suite finished with one failing UI test, program
input typed 32 instead of 3. All other active tests passed. The exact program
journey passes 332.761s with the new helper, reminder 141.628s, and all 160
active hosted tests pass. These replace the failure, but do not call the old
full bundle green. A fresh complete run now partitions all 46 UI methods
exactly once across three separate fixtures, with every hosted test in group 1.
Manifest and logs are in release artifacts/design/complete-*. Integration is open.

Small-light native audit passes with all audit types. Eight hosted training
presentation tests, including exact weight preservation, and weight offline/
conflict/deletion/undo 86.735s pass. Small-dark audit 39.479s, empty captures
31.885s, and secondary captures 75.475s pass. Both themes now pass after exposing
and rechecking rows that were under system chrome. The iOS 26 large-dark audit
found one further potential inaccessible-text issue with no element attached.
Macro VoiceOver values now include targets, and the visible Today label is
included in its accessible name. The exact large audit is rerunning. Do not
claim the entire matrix is clear yet. Latest device and 61 owned Swift files pass.

Reviewed 36 secondary images in contact-review, small light and large dark,
covering account, sync, agents, health, activity, sleep, weight, measurements,
milestones, nutrition program, password, Health permission, preferences, food
label/picker, new workout, training empty, and photos empty. Against Things 3,
our faint default placeholders made the inputs seem disabled. They now use the
readable secondary text token. Repeated password placeholders were removed.
Against MacroFactor, 159.284 lb and eight-decimal height read as raw storage;
weight and height now show at most two decimals without resaving rounded data.
Against Workouts, the new-session introduction displaced the fields; removed
the filler heading and combined the name and explanation into the first card.
Activity/sleep presets, weight controls and food nutrient fields retain the
shared layout. Primary summaries retain Fitness-like emphasis, with Exerly's
purple/pink rather than new colors or branding.

P1 remains in Logic's inbox at 02:44: legacy SyncEngine never clears error after
a successful pull and leaves isOffline set when reconnecting with no pending
mutation. The combined app Sync action now uploads water correctly, verified
607 ml after offline U.S. entry and relaunch, but the honest combined status
continues displaying that stale error. No Core source workaround or exclusion.
This is the remaining failing U.S. regression assertion. Continue owned design
review and integration while Logic fixes the status. No new nutrition features
before the design TestFlight release and its final independent critique.

## Final U.S., sync and accessibility work, 2026-10-07 02:38 EDT

Ali explicitly requested continued autonomous work for several hours and major
completed improvements. Continue through the brief, not just this release.
Primary rebased on Logic's e0bce0e7, preserving Logic's inbox status updates.
Core 295, API 250, device and 61 owned Swift files pass. Full hosted and
program/reminder journeys are running on current source. The fixed older full
run has a program numeric-entry failure, 32 instead of 3, with later tests
continuing. The helper now verifies and retries real input through selection.
The previous full-focus-dark run was interrupted, not completed or green.

Water now uses fluid ounces through USUnits, setup/profile feet and inches use
Core, and the diary adopts preserved target plans and displays kcal left.
A new real-API U.S. water journey passed entry/validation/offline/relaunch but
caught a real sync-screen gap: Core reported synced before legacy water was
uploaded. AccountSyncView now asks both engines to sync and reports pending or
review states. The regression is rerunning. Metric remains an explicit choice.

The native audit caught undersized tap regions, unreadable email naming, and
caption2 Dynamic Type scaling. Those are fixed. A custom saved-food search field
now passes its search/clear/edit/archive/offline journey, 168.221s. Remaining
contrast findings were rows under system chrome. The audit now scrolls those
rows into full view and audits them again, with no label exclusions. Both
appearances are running. Token contrast alone was insufficient evidence.

Photo import, compare, detail and relaunch pass at largest text, 65.851s, plus
secondary capture 133.613s. The fixed three-row Progress choice was taking too
much vertical space on SE, so it becomes one labeled menu at accessibility
sizes. Inspect photo-menu-ax-dark for the corrected result. Rounded preferences
passes five hosted invariants and the real-API recovery/conflict journey.
Gallery includes latest default small-light and large-light/dark plus these
accessibility captures. Final Logic critique and design TestFlight still pending.

## Fixed design candidate, 2026-10-07 01:44 EDT

Committed conflict review b050a875, U.S. defaults 01c4e6c2, accessibility layouts
9b68ae18, and photo/admin capture plus automation fixes 67ed9442. Device build
passes at this source; all 59 changed app Swift files pass SwiftLint with no
violations. Core and API remain untouched. Full native now runs in the reused
release worktree from fixed 67ed9442, with its own fixture on 39221.

The exact manual-food iOS 26 journey passes 177.820s with the keyboard-aware
helper. Interrupted setup, barcode, offline relaunch and reconnection pass
221.890s in us-input-recovery. The earlier U.S. run had a stale assertion:
it checked today's target on yesterday's page, before a fresh account had any
targets. The corrected check verifies today's target and no target yesterday.
The U.S. setup-default assertion itself passed before that failure.

us-ax-small-light passes all three capture journeys; us-ax-small-dark passes
those three plus admin. Review found the admin role still narrowing the name,
so that row now stacks at accessibility sizes. Preferences now uses a compact
name/status header. Password and setup shed redundant headings and copy.
Refreshed release-large-light and release-ax-small-dark captures are running.
The latter includes real photo import/comparison at largest text. The first
setup capture caught a late system password prompt; capture settling is fixed,
and the old image is not release evidence.

full-focus-dark continues to collect evidence but remains a failed earlier
run. Its three failures have passing targeted replacements. Program builder,
lifecycle and program proposals pass. Do not call it a passing full suite.

U.S. energy is nutritional Calories, currently labeled kcal; body weight uses
pounds and setup height uses feet/inches. Existing explicit metric preferences
stay metric. Water still uses milliliters pending Logic's public fluid-ounce
conversion and Core/API missing-preference defaults. No release claim that
water is already converted.

## Design evidence and U.S. defaults, 2026-10-07 01:28 EDT

Foundation 60e83cf9 is now merged and pushed. The full foundation suite is
green, 143 active hosted and 30 active UI tests, eight optional skips, with
Core 290/API 246/device gates. Its release worktree is free for reuse.

Latest default captures pass on all four size/theme combinations. They contain
27 design views each, with admin overview/accounts also in final-small-dark.
The small-dark run also passes the full water offline/merge journey. Photo
import/comparison/detail/relaunch passes in photo-import-comparison using two
geometric PNG fixtures. Both images were selected through the real system
picker; the comparison and detail screenshots were reviewed.

Largest-text review found narrow food rows, broken water amounts, duplicated
Sync symbols, and narrow email headers. Food and water stack vertically at
accessibility sizes; decorative identity icons no longer consume text width.
Reviewed the corrected small-light food and water captures. Sync uses a single
icon and a full-width last-sync line. Preferences repeated its save explanation
and displaced fields; its status/refresh now sit inside the summary.
Contrast report passes 74 text/fill pairs at >=4.5:1, minimum 4.51.

Full primary full-focus-dark is still running and is not green. It found two
old empty-suggestions assertions, both now pass in entry-check-summary, and a
manual-food automation tap under the keyboard toolbar on iOS 26. The helper
now dismisses an occluding keyboard before replacing a field. Retest that
exact manual-food journey on large iOS 26. Search/barcode/repeat passes 137s.

Conflict screens are now app-owned SavedChangesReviewView, using existing Core
Issue/server-version/resolution operations and preserving reviewed revisions.
Original Core UI is untouched. Device build and activity/sleep, measurement,
and weight conflict/offline/undo journeys pass in saved-change-conflicts.

Ali's latest steering is to default Calories and units to U.S. Fresh setup now
uses U.S. regardless of device locale; app fallback preferences use imperial.
Setup exposes feet/inches and pounds, with Core Mass for lb conversion. Metric
remains an explicit saved choice. Two hosted conversion/default checks pass;
signup and primary U.S. captures are running. Core/API missing defaults and
public fluid-ounce conversion are requested in Logic's inbox; do not invent
conversion arithmetic in app code. The current water UI still uses ml.

Remaining gates: U.S. final capture matrix/review, photo/admin accessibility,
remaining secondary-route comparisons, passing full current native suite,
Logic final critique and unit contract, then fixed-commit internal TestFlight.
New nutrition features remain paused.

## Current evidence, 2026-10-07 00:19 EDT

The foundation at 49164782 passed 143 active hosted and 30 active UI tests,
8 optional skips, zero failures. Rebased onto 3425db1d as 60e83cf9; new Core
290/API 246/device gates pass. Full native rerun is active from that fixed commit.
The separate secondary light baseline run uses its previously built 49164782 app.

Primary `signup-programs-dark` passes both design journeys, the full program
builder and interrupted signup/barcode/offline recovery. `targets-library-primary-light`
passes 14 hosted nutrition tests, both design journeys and library edit/archive/
restore/relaunch/sync. Keypad button entry and prefilled training pass in
`keypad-buttons`; its unrelated library case failed the uppercase Archived
accessibility label, which the newer library run fixes and verifies.

Visual review: target bars now appear from reviewed saved targets. The custom
keypad Done header is visible and usable on SE. The Progress tabs broke long
words at default size; shortened to Body/Photos/Milestones. The library repeated
its title and marketing copy; removed. The diary status card competed with meals;
changed to a compact menu beside diary actions. Latest captures remain prototypes.
Logic's 2026-10-07 intermediate critique is received, fixes are in progress.
Program/measurement/photo secondary routes are now included in the design pass.

## Design review and tests, 2026-10-07 00:41 EDT

Gallery: http://100.80.149.7:39215, served from primary artifacts/design.
App captures use synthetic accounts. The reference images
were fetched again at full size from Apple's public CDN; sources.json records
each URL. Gallery defaults to a UI screenshot instead of the reference's cover.

`compact-small-light` passes all three capture journeys and measurement offline/
relaunch/conflict/undo, 4 UI tests. `compact-small-dark` passes the three capture
journeys plus note/copy/deletion/undo, 4 UI tests. `compact-large-light` passes
all three capture journeys. Those bundles contain 27 design views each. The
small dark and large light builds include the denser diary summary and a single
first-weigh-in state. Later focus, placeholder and contrast fixes need refreshed
captures. Largest-type light captures are now running on both sizes.

The first `full-current-dark` run passed 159 hosted tests, 1 optional skip, then
found a real Sleep focus bug. Bedtime and wake time shared one Boolean focus
binding. The keyboard could remain on bedtime after tapping wake time. That run
was interrupted, not counted as a pass. Sleep now has separate focus values.
Food/activity editors no longer attach one Boolean to several text fields. The
replacement helper also avoids triple-tapping placeholder text. Full native
`full-focus-dark` is running. Its code predates the final header/contrast tweaks.
Device builds through focus/density pass. SwiftLint has warnings but no errors;
lint has the same 18 web warnings, typecheck passes. Core/API code is byte-identical
to the foundation's passing 290/246 results.

Critique against MacroFactor/Workouts/Fitness/Things: Exerly's first meal still sat
too low on SE. Reduced summary gaps, moved target beside calories and grouped the
status line with the summary. Progress repeated a first-reading message in an
empty chart; it now offers a weigh-in action in one summary, followed by history.
Library repeat rows now say Log again with the last portion and a plus action,
so they are distinct from saved-label editing. Removed oversized numeric-field
placeholder labels. Account email should not occupy a hero-sized card, so it now
uses a compact identity row. These are presentation fixes, not new nutrition work.

Contrast audit found original dark purple text below 4.5 on two dark surfaces.
Original brand/chart/logo values are unchanged. Added a lighter purple text role
and reused the existing deep purple for white-text filled controls. Final ratio
report and four-mode capture review remain required before upload.

Still pending: final default and largest-type review, Core-owned conflict views
extraction, photo comparison/admin routes, Logic's critique of final captures,
full passing native suite and fixed-commit TestFlight design release.

## Design pass progress, 2026-10-06

Shared design controls committed as `359fafef`, device build passed. The first
foundation batch passed the full native suite at `f282fdd2`: 30 active UI tests,
7 optional skips, and hosted tests. It was rebased onto current integration
`401d8203`; rebased commits are `28282bb3`, `efa14ca3`, `1c2cf5b7`, `49164782`.
Core 288/API 243/device/lint/typecheck/format gates pass on that rebase. Full
native suite runs again from the fixed `49164782` release worktree. Integration
remains open to Logic. Land this batch when the suite is green.

Implemented in the working tree: summary-first diary/training/profile/progress,
shared number styles and controls, food label/amount/library/detail, set editor
and keypad, programs/history/insights, agent/account headers, compact offline
notice. Daily-health editors and remaining secondary routes are being designed.
No final visual approval or design release yet; nutrition features remain paused.

Real-API design checks: `keypad-manual-current` passes 13 hosted nutrition tests
and the manual offline/relaunch/sync journey. All four captures reviewed. The
food amount selector wastes space when grams are the only choice; now hidden
in that case. The diary's sync explanation displaced its summary; moved below
meals. The historical volume-label regression failed first in `volume-red` and
now passes with snapshot volume retained. `compact-day-library-current` passes
the day-note/copy/delete/undo and historical library journeys, before the latest
food-detail toolbar/menu changes. `secondary-device` passes before later edits.

`session-keypad`, `session-current` and `session-fixed` are not green evidence.
The first exposed a missing keyboard Done control on New workout, fixed. Later
runs exposed stale indexed XCTest navigation-button queries while dismissing
share sheets, and the custom keypad obscuring the second set field. The helper
now recognizes the custom keypad and binds navigation elements by accessibility
identity; Save set moved into the toolbar to preserve editing room on SE. Retest
these exact flows and inspect the visible-keypad capture before calling it done.

Ported the legacy food/status/calendar/daily-health/weight/signup UI journeys to
the new Core diary and destinations. Kept exact offline, revision, unknown/zero,
precision, snapshot, cross-device conflict and relaunch assertions. The old
nutrition-label edit expectation now explicitly preserves the old entry snapshot
and uses the corrected label only for a new entry. Account-calendar already
passes in `legacy-routes-current`; other journeys are still running.

Before default-size captures: all four size/theme combinations, 16 images each.
Public MacroFactor/Workouts/Fitness/Things screenshots and the first primary
comparisons were reviewed. `editors-primary-light/dark` pass. These are prototypes,
not final release captures. Remaining before images, all secondary captures,
final four primary variants and Logic's final critique remain release gates.
See `docs/design/020-design-quality.md` for route audit and reference comparison.

## Current work and next steps

Ali's21:17 steering is the top priority. Read updated Integration and Design
quality sections ofAGENT_BRIEF at6b908a24. New features are paused. Finish landing
existing nutrition work in passing pieces; consolidate into the primary
Exerly-Fitness-app plus one release worktree. Keep this merge table current.
Then do a full design pass on every existing screen before resuming nutrition.
Default-size light/dark before/after captures and public App Store comparisons
are a release gate, alongside accessibility captures. Logic must critique the
captures. Do not freeze integration for release tests; use a fixed commit.

A6 is released as2610070024, VALID/IN_BETA_TESTING, only Ali/only build, notes
verified. Full132 hosted+30 UI pass,8 skips,0 failures; Core259/API238/device pass.
Original purple/pink and E/pulse mark retained. All4 program and4 meal AX
variants reviewed. A6 archive and evidence remain in app-programs.

A7 current implementation: NutritionStore account sync/proposal/export hosts,
manual label and amount editors, submitted search and barcode, diary/status/
notes/copy, guarded deleteundo, recent previous portions and native food library.
No new feature work until the design release. Do not edit Core/API.

A7 evidence under artifacts/nutrition:

- Composition12, food drafts9, guarded delete11, repeat/search16, day/search21
  hosted tests pass; meaningful regressions failed first.
- library-actions-green6 and favorite-green7 pass, missing interfaces failed
  first. Actions preserve snapshots and refuse changed reviews.
- manual-first real-API journey PASS253s: create380kcal oats/fat0/ironunknown,
  37.25gDinner yesterday offline, relaunch/edit40.5/relaunch/sync; exact server
  record checked. All4 named captures reviewed.
- search-barcode-first PASS805s: submitted search only, barcode hit/miss,
  3tap35.5g repeat, server3entries [20,35.5,35.5], provider counts. All4 reviewed.
- day-actions-hitarea PASS216s: partial/note/copy/deleteundo/relaunch/sync with
  exact records. All7 captures reviewed. Earlier failures exposed narrow Menu
  hit area; fixed full-width44pt target. Earlier first/toolbar bundles fail.
- library-name-fixed PASS89s: favorite, label edit, new log, archive cancellation,
  archive/restore, offline relaunch/sync; historical57kcal label stays unchanged,
  new60kcal label used only for new entry.6 named captures await visual review.
  library-first interrupted; library-inputs-fixed failed name replacement.
  Helper now triple-taps existing multiline names as A6 already did for programs.
- diary-current-device and library-device pass. Library SwiftLint found one
  catch positioning warning; fixed, recheck before commit/landing.

Design critique before work: the new diary/library and training screens lean on
stock rows. Diary date/settings/explanations compete with the totals; empty meals
repeat the same blank message and Add action. Library opens with explanatory
copy and a stock toggle, not recognizable foods. Numeric fields and selectors
have no consistent hierarchy. Purple tint alone does not make these screens
Exerly. Current mono number fonts also contradict the new proportional-rounded
requirement. These all must be fixed before the design TestFlight release.

Reference images downloaded from official Apple lookup/App Store pages under
artifacts/design/references for MacroFactor, MacroFactor Workouts, Apple Fitness
and Things3. Not yet inspected. Record comparison after viewing them; no copying
of assets or private interfaces. frontend-design skill read; native constraints
and Ali's purple/pink identity take precedence over its generic web defaults.

Next: rebase/land tested pieces; finish cleanup; capture current primary and
secondary screens; implement shared design system and redesign all visible
flows; test/compare/review/release design, then resume unfinished nutrition.
Incoming snapshot volume and barcode symbology correctness fixes may be adopted
while reconciling; new target/coaching/import features wait for design release.

Resources: primary `/Users/aldo/Desktop/Exerly-Fitness-app`, branch
`agent/app-nutrition`. One release worktree, `Exerly-Fitness-app-programs`,
at `60e83cf9`, now landed. Its full suite `artifacts/foundation/rebased-native.xcresult`
passes with Core/API/device gates. Release worktree can now be reused for the design release.
Primary design uses free SE `45D463AE-8D3E-4D8F-BD35-CE70128BF962`,
fixture39212/session71288, and large `02A671D3-2CEC-4F96-8E25-FFA8FEFB9F19`
with fixture39213 to start. Old nutrition and app-next worktrees removed.
Do not touch Logic sims or protected services. Credentials only in private_keys;
phone requires Tailscale. Use `DEVELOPER_DIR=/Applications/Xcode-26.2.app/Contents/Developer`
and author Ali. Main integration is being handled by Logic in its own temporary
worktree; do not interfere.

## A3 final evidence and release

- `artifacts/account/full-a3-canonical.xcresult`:100 hosted +19 UI pass,
  eight opt-in skips, zero failures. Completed15:47 EDT. API219/Core183/device
  pass in canonical-{api,core,device}.log. Lint/format/typecheck/SwiftLint pass
  in `canonical-*` logs. Existing warnings only. Six Node/seven Python release
  checks pass in `final-release-*` logs; release scripts unchanged since.
- Four final largest-type account variants pass, two journeys each. All36
  screenshots inspected in account/{small-light-final,small-dark-final,
  large-light-final,large-dark-final}. Earlier32 recovery +11 normal captures
  also inspected. Banner and Start workout wrap fixes verified.
- Earlier full-a3-current had one legacy test-hook port failure, fixed and
  focused verified. full-a3-final was interrupted to adopt700cdc0d. Neither
  is the final evidence; full-a3-canonical is green.
- Signed archive/IPA1942 passed validation. Upload success15:49 EDT.
  `apps/ios/build/release/2610061942/{Exerly.xcarchive,export/Exerly.ipa,upload.log}`.
  Obsolete1907 and1727 must not be uploaded. Upload session49030 finished.

A3 native Apple buttons validate nonce/state/token and call the shared Core
bridge. Account methods link/unlink, Apple-only guard, export/share, explicit
reauth/deletion. AppAccountWorkspace shuts down Core sync before account
changes, consumes persistent confirmed cleanup queue and resumes sync after
failed deletion. Training persistence is account-specific; hosts training+agent.
Automatic foreground/120sec sync. Account export merges unsynced training and
proposals; offline export works. UI discloses pending legacy rows excluded.
Core now supplies queue export and explicit persistence close; wire into A4.

Root account notices sit above auth/TabView so they do not cover Back on iOS18.
Saved-account banner describes cached details rather than incorrectly declaring
training offline. Welcome uses original mark, scrolling/Reduce Motion, wrapping
copy and opaque auth back button. Start workout wraps at largest type.

## A4 implementation and evidence

Design008 and tests preceded implementation. Four Features/Agents files, two
hosted test files, project registration, Profile Connected agents and Training
Suggestions entry are in app-next. AgentReviewModel uses Core accept/reject/undo,
including stale/invalid refusal and sync of refusal audits. Full field diffs,
unit presentation, raw JSON fallback, verified/mismatch/unavailable metrics,
evidence/caveats/confidence/falsifier, offline decisions and activity history.
Stale refusal scrolls into view and receives VoiceOver focus.

Tokens use account-bound API. Default read+propose; read-only available; direct
write requires explicit native alert with Cancel. Secret masked until Show,
copy is local-device-only with ten-minute expiry, clear on Close/disappear,
hide on background and discard a creation completing after Close. Revocation
requires confirmation and remains reflected if the subsequent refresh fails.
Permission label wraps through Menu/Picker, fixed37299a9d.

- Eight hosted tests pass, including actual store decisions and token races.
- Real-server UI: offline accept/relaunch/sync/undo/reject/audit; stale proposal
  preserves later workout edit; token default/masking/revoke/cancel/direct-write
  cancellation. No token secrets printed or exposed in test captures.
- Normal SE three journeys pass across real-api-first/offline-navigation-fixed;
  all13 images inspected.
- large-dark-scroll and large-light-canonical: eight hosted+three UI pass.
  All13 and14 images inspected. Permission picker clipping found, fixed37299.
- small-light-canonical review failed only upward gesture after undo. Helper
  now drags inside visible list below account banner (4d89933a). Not passing
  evidence. All13 captures inspected.
- small-light-final: all three UI pass; all14 images inspected.
- large-dark-final: all three UI pass; all14 images inspected.
- large-light-permission-final: focused connection journey passes; all5 images
  inspected. Completes verification of picker correction in light mode.
- small-dark-final: all three UI pass; all14 images inspected.
- Device build passes after picker fix in agents/permission-device.log.
- Full native A4 suite active as listed above; A4 TestFlight pending.

Native alerts remain scrollable at largest type; test both Cancel and confirm.
Exercise evidence links currently explain unavailable; A5 will link to logged sets.

## Logic handoffs and reviews

Logic worktree /Users/aldo/Desktop/Exerly-Fitness-logic, last seen branchlogic/next
at7ba4f44e. It waits for A3 landing before M4/M5. App must not edit Core/API.
Integration /Users/aldo/Desktop/Exerly-Fitness is merge-only, never edit files.
App writes docs/handoff/to-logic.md in primary and logic worktree for timely review.

Reviewed migrated UUID issue; exactfix700cdc0d adopted into A3/A4. Reviewed
M4 weightMatch inert toggle: Logic explicitly reserves it now, omit from UI.
New medium plate finding: greedy80kg/bar20/25pair1+15pairs2 returns70 despite80
achievable; target10/bar20 reports zero shortfall. Reproduction in
artifacts/app-review-plates/result.log. Inbox asks best combination and clear
below-bar outcome including warm-ups. A4 remote4e696163 review requested.

Available contracts on logic/next, not yet integrated:

- b9736776 SQLiteTrainingPersistence.close(); deleteDatabase closes all instances
  for that path. Use close on switch/signout. Reads/writes after close throw.
- ecccb9fd AccountExport.merging(... pending: try SyncEngine.shared.pendingExportRows()).
  Overlays all legacy queue entries/deletions with pending_sync; remove exclusion
  copy. Adopt hosted attachment docs/handoff/attachments/LegacyExportTests.swift.
- 00d9992f entry detector stable identity per workout and accurate same-workout
  evidence, reject/undo wins. App A5 design009 uses this unchanged API.
- ProgramStore + ProgramSchedule nextWorkout/lifecycle/overrides, sync and agent
  host support. A6 design010, omit reserved weightMatch and await plate fix.
- NutritionStore domains, energy-balance/trend estimates. Targets/search/import
  still forthcoming from Logic; no nutrition UI started yet.

## User corrections and credentials

Ali rejected mint/green. Preserve original purple/pink, neutral dark, dark default,
existing purple E/pulse mark. Profile can select Light/System. Icon source
apps/ios/Brand/ExerlyMark.png; render-icon.swift sizes it. No brand redesign.

Old1633 could not sign in to incompatible DO API. Live1654 uses working staging
http://100.80.149.7:39110; phone must enable Tailscale. Synthetic login/bootstrap
passed, credentials already sent in chat and stored only in
~/private_keys/exerly-testflight-account.json mode600. Never print or commit them.
Physical replacement install/login not confirmed. Do not persist Mac password.

## Signing and infrastructure

Exerly ASC6819776832, en-US, SKUsideband-exerly-ios, bundlecom.exerly.fitness,
team9X79V37Q89, bundleresourceUJ5X8TJKNL. Record created website12:27 EDT.
Internal groupc5ae1d39-0fe4-4bee-af89-0374d9519afe Exerly Internal · Ali,
only Ali, no public link/autofuture. Existing dist certificate expires2027-09-25;
never create/revoke. ProfileJ5J395Y9AF HealthKit+SIWA. ASCkey4Z7KFJ8DWZ/issuer
under ~/private_keys. Never expose. Live1942 UUID17311f01-34dc-4a20-9171-7343ce4ccf39.
Production Neon/DO and Apple revocation credentials are existing Ali questions,
not a reason to stop UI work. External/App Review requires Ali after preparation.

Always DEVELOPER_DIR=/Applications/Xcode-26.2.app/Contents/Developer, including
push hooks. Origin sidebandstudio/Exerly-Fitness verified with gh15:48 EDT.
Commit as Ali Younes, no coauthor/tool attribution.

App sims only, never Logic sims:

- Original Large7189880A-91EC-4555-83E8-A37464802FE6,17ProMax26.2, main
  .deriveddata/app-account, fixture39203. Free after A3 full suite.
- SE7D2096B8-3E67-477F-82BF-0E2BEDF2CA2B,SE3/iOS18.6, app-next
  .deriveddata/a4-review, fixture39204. Current small-dark run.
- Accessibility Large02A671D3-2CEC-4F96-8E25-FFA8FEFB9F19,17ProMax26.2,
  app-next .deriveddata/a4-large, fixture39205. Free.
- Device derived data account-device or a4-device by worktree.

Use -parallel-testing-enabled NO, unique result bundle. TEST_RUNNER_EXERLY_TEST_APPEARANCE,
TEST_RUNNER_EXERLY_TEST_LARGEST_TYPE=1, TEST_RUNNER_EXERLY_UI_FIXTURE_URL and
EXERLY_FIXTURE_EXTERNAL=1. Existing fixture39203/4/5/6 sessions3247/7679/53930/93999,
current700cdc0d source, logs account/canonical-fixture-<port>.log. Environment
EXERLY_FIXTURE_PORT, not PORT. Verify PID/cwd before stopping a fixture and never
while tests use it. Protected devbox services untouched.
