# App agent ledger (Astra)

Read AGENT_BRIEF.md, this ledger and to-app.md after every reset. Done is not
met. No parity row is fully device-verified. Continue without ending at a
milestone. Current date 2026-10-07, updated 04:29 EDT.

## Merge status

Integration is `87abfb67`, merged and pushed at 04:11 EDT after the complete
native suite, Core 295, API 250 and device build passed. Primary plus one release
worktree. No integration hold.

| App branch                         | Unlanded work                                                                                                      | Last landed / cleanup                                                                                           |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------- |
| `agent/app`                        | None, `git cherry` empty after the duplicate historical note was skipped                                           | Deleted locally and remotely; primary worktree now uses nutrition                                               |
| `agent/app-next`                   | None, `git cherry` empty                                                                                           | Deleted locally/remotely and worktree removed; A4 captures/releases preserved in primary `artifacts/retired-a4` |
| `agent/app-programs`               | None, `git cherry` empty                                                                                           | A6 landed `19925b28` at 21:13; local branch deleted, remote deleted at 21:38                                    |
| `release/app-nutrition-foundation` | None; branch deleted after foundation landing                                                                      | Landed/pushed 60e83cf9 at 01:00; native 143 hosted/30 UI, Core 290/API 246/device pass                          |
| `agent/app-nutrition`              | Three Health/evidence commits through 4186a492; final volume formatting under review; combined sync in named stash | U.S./accessibility batch 87abfb67 landed and pushed 04:11                                                       |
| `release/app-design`               | Fixed 4186a492, Health delta beyond 87abfb67                                                                       | Previous 87 passed; complete 48-method Health suite now running in three groups                                 |

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
