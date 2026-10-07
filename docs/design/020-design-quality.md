# A8: design quality pass

Ali's 2026-10-06 correction takes priority over nutrition feature work. Preserve
the original E/pulse mark, purple and pink, and dark default. This pass changes
presentation and input controls across existing routes. Core remains the only
source of domain calculations. Never replace missing nutrient data with zero.

## Direction

A quiet training and nutrition instrument. The number or next action that makes
the screen useful comes first. Purple identifies actions and energy/protein;
pink distinguishes carbohydrate. Neutral cards separate groups without turning
each field into its own box. SF text and rounded proportional numbers scale with
Dynamic Type. Only clocks and aligned digits use mono.

Use one spacing scale, 4/8/12/16/20/24/32, with 24-point continuous cards and
12-point controls. ExScreen, ExCard, headings, action buttons, choice chips,
quantity controls, progress bars and empty states live in DesignSystem.swift.
All interactive controls are at least 44 points. Accessibility layouts stack
instead of shrinking text. Native permissions, sharing and destructive
confirmations retain their platform behavior.

## Reference review

Public App Store screenshots downloaded from Apple's lookup API are in
`artifacts/design/references`. These are references for hierarchy and behavior,
not assets to reproduce.

- [MacroFactor](https://apps.apple.com/us/app/macrofactor-macro-tracker/id1553503471):
  compact food rows keep name, portion and macros together; frequent actions
  are immediately available. Exerly previously spent the first viewport on
  dates, nutrient caveats and logging status, before showing any food.
- [MacroFactor Workouts](https://apps.apple.com/us/app/macrofactor-workouts-tracker/id6737156524):
  previous and current sets are visually comparable, with large numeric entry.
  Exerly had one stock navigation row per destination and small generic fields.
- [Apple Fitness](https://apps.apple.com/us/app/apple-fitness/id1208224953):
  the daily summary dominates, then distinct supporting information. Exerly's
  equally weighted cards made everything look like a setting.
- [Things 3](https://apps.apple.com/us/app/things-3/id904237743):
  spacing, alignment and restrained color make a dense list readable. Exerly
  used purple text equally for primary, secondary and destructive-adjacent actions.

Logic's independent critique in to-app.md adds compact note/confirmation sheets,
human dates, rounded display values, and a compact offline state. Incorporate
these without weakening stale-edit guards, historical snapshots or recovery.

## Screen audit checklist

| Area                 | Existing routes                                                                      | State                                                                          |
| -------------------- | ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| Diary                | Daily summary, populated/empty meals, date, status, notes, copy, undo                | Reviewed in default themes and AX; full native journeys pass                   |
| Food                 | Picker, search, barcode, label editor, amount editor, saved library/detail           | Reviewed shared label, portion, keypad, library and repeat; full journeys pass |
| Training             | Home, active workout, set editor, notes, rest timer, exercise picker/detail          | Reviewed summary, prior/RIR rows and keypad; full journeys pass                |
| Programs             | List/detail, builder/day/slot targets, overrides, planned workout, lifecycle reviews | Reviewed in light/dark and AX; relevant native journeys pass                   |
| History and insights | History/detail, exercise logs, observations, source-set links                        | Reviewed in light/dark and AX; relevant native journeys pass                   |
| Agents               | Inbox, proposal review/diffs/evidence/audit, tokens/create/revoke                    | Reviewed in light/dark and AX; relevant native journeys pass                   |
| Progress             | Measurements, weight/chart/history/edit/conflicts, photos, achievements              | Reviewed in light/dark and AX; relevant native journeys pass                   |
| Account              | Profile, preferences, appearance, password, account export/delete, sync, Health      | Reviewed in light/dark and AX; relevant native journeys pass                   |
| Daily health         | Activity/sleep/water summaries and editors, conflict/undo                            | Reviewed in light/dark and AX; relevant native journeys pass                   |
| First run            | Welcome, email/Apple login, signup, setup/repair/results                             | Welcome/sign-in/setup reviewed; automated signup/recovery pass                 |

Unreachable legacy food/dashboard/social/coach screens are not product routes.
Confirm the call sites before removing anything. Admin is only visible to an
admin account; it remains in the audit if that route is reachable.

## Evidence and release gate

Before captures at default type: `before-small-light`, `before-small-dark`,
`before-large-light`, `before-large-dark`, 16 named images each, from opt-in
ProductionUITests. The matching xcresult bundles preserve the originals. Some
early iOS 26 diary images caught the system password prompt animating out;
the capture helper now dismisses it and waits before design screenshots.
Primary and secondary small-light views reviewed, with fixes recorded in the ledger. Finish reviewing the
remaining images and add secondary-route capture journeys.

After each design group: device build, affected real-API journeys, default
light/dark captures, largest-type captures, screenshot review against the
references, and Logic review. Full native/Core/API/repository gates before
landing and TestFlight. Release from a fixed commit in the single release
worktree. Notes must describe the design changes. New nutrition features resume
only after this design release.

## Candidate 67ed9442

The shared system now covers all reachable app-owned routes, including saved
change conflicts, admin, photo import/comparison, daily-health entry, setup,
password, Health and preferences. Conflict resolution still calls the existing
Core API with reviewed revisions. No Core or API source changed.

Largest-size review led to stacked food/water/admin rows and full-width account
emails. Secondary headers were shortened where they displaced their controls.
All 74 audited token pairs meet 4.5:1, minimum 4.51. The final source compiles for
iPhone and has zero SwiftLint violations in the 59 changed app files. Final
matrix review, Logic critique and the full fixed-commit native suite remain
release gates. The current gallery is a review artifact, not a release claim.

## Final review refinements

The small-phone native accessibility audit now passes in light and dark.
Full-size contact reviews of 36 secondary captures found faint placeholders,
raw weight precision, a repeated new-workout introduction, and dark primary
buttons using the chart purple. Shared input hints and action colors now use
the readable roles. Weight display preserves the exact stored measurement when
only a note changes. The large iOS 26 audit and refreshed final matrix remain
in progress. Native audits scroll content clear of system chrome before
rechecking a contrast finding; no element label is ignored.

Capture review sheets are in `artifacts/design/contact-review`. They reference
the unchanged original captures rather than editing them. The gallery records
the source run for each image. Passing tests, visual review, Logic critique,
and internal TestFlight remain separate evidence.

## Review of detailed routes

The first full design batch is merged at b7b082b7. Its 160 active hosted tests
and 38 active native journeys pass. The refined candidate 87abfb67 adds U.S.
water, target progress, readable keypad fields and confirmations. It is in a
fixed full run while integration remains open.

Ten additional contact sheets cover 30 program, training and agent screens.
The review caught truncated program introductions, duplicated navigation
chevrons and stock confirmation buttons. Those are corrected. Default small
light/dark native audits pass. iOS 26's selected Body segment failed contrast;
purple selection with white text passes the isolated audit.

Health review found success marks for unsupported sleep/workout data and a
write-permission request under a read toggle. The app-owned permission layer
now requests only the two displayed read types, scopes its preference by
account/environment, and leaves denied or missing reads unavailable. It never
infers read authorization from completion of Apple's permission sheet. Native
physical Health authorization remains a separate verification requirement.

## Final comparison review, 2026-10-07 04:29 EDT

Eight before/after/reference sheets are in `artifacts/design/contact-review/final-*`.
Reviewed diary, training, saved library and Progress in both default themes.
The MacroFactor comparison now uses its actual logger screenshot, not the cover
image; Workouts uses its schedule screenshot. Things supplies the dense-list
reference and Fitness the summary reference. The original large-light before
Diary has a system password prompt and is retained with that limitation; its
small-phone before capture is the unobscured baseline.

The old diary put date, explanation and logging status ahead of food. The new
summary keeps target, remaining Calories and macro bars together, with meals
immediately below. The library adds an explicit recently logged action while
removing the repeated introductory paragraph. Progress no longer presents a
single weigh-in as an empty chart surrounded by four equally weighted metrics.
Training makes the next day and its action distinct from history and navigation.

One remaining rough edge was a three-decimal total volume in Last session,
4188.783 lb·reps. Display whole grouped totals in that card and history detail;
stored sets keep their precision. Singular working set is corrected too.
Health now puts its read switch before the explanation, including largest type.
The native permission sheet exposes exactly two read types and no writes; its
relaunch flow passes. Full iOS 26 light accessibility audit passes, 62.570s.
Largest-type program builder completes offline/relaunch/advance in 596.150s.
Photo import, comparison, detail and relaunch pass again at largest text.

## Final critique follow-through, 2026-10-07 05:30 EDT

Logic's ten-point critique is addressed in the final design candidate. Set
previews use a compact table at ordinary sizes and readable stacked rows at
accessibility sizes. Program choices are inline, validation stays beside the
days, and the sheet toolbar has an opaque background. Proposal differences
show grouped old and new values before their source links. Evidence wording
does not mistake one person's records for exactly one workout. Account exports
have a dedicated route with an automatic offline choice and explicit omissions.
The fixture MCP endpoint remains DEBUG-only; the compiled device endpoint is
http://100.80.149.7:39110, so the release endpoint is its /mcp path.

Reviewed all 37 new small-phone largest-text captures across 13 contact sheets,
critique-small-dark-ax-01 through -13. Compared with the reference apps' concise
action hierarchy, the export and agent introductions still displaced their
buttons. Moved those actions ahead of the explanation and shortened the copy.
The same problem in shared empty states now uses the action before the smaller
explanation at accessibility sizes, with the decorative icon omitted there.
The agent name can wrap instead of truncating.

The weight editor capture showed a large date-control region above the actual
input. Weight now comes first, and the reading date has its own labeled compact
card. Capture waits for the loaded weight field. These final layout changes
require refreshed default and accessibility captures; the current 37-image
set is retained as evidence of the findings, not as proof of their correction.

## Final control review, 2026-10-07 06:42 EDT

The complete5b2c9f92 suite passed167 active hosted tests and40 active UI journeys.
Thirteen further small-phone largest-text program captures were reviewed after
the full program journey passed. Ordinary menus had failed to open at AX sizes;
those controls now use readable selection sheets with a checkmark and cancel.
Default-size controls remain compact. Stale program validation clears on edits.
The wrapping agent-name field now treats Return as completion, dismissing its
keyboard. Empty-state actions and Export appear before explanatory copy.

The final review caught a hyphenated account notice at the largest size. Hiding
its decorative icon at AX gives the wording room without changing its meaning or
Retry action. Final default-theme captures and this narrow AX check are separate
from the already-passing full baseline. The final candidate is8e1488c2; the source
for signed build2610071041 is fixed in the one release worktree.

## Final upload, 2026-10-07 06:59 EDT

All eight default-size comparisons now use the final primary captures. The
small-phone AX primary and offline/account captures also pass. Reviewed the final
navigation rows: Barcode is a whole word, Connect an agent wraps at word boundaries,
and Saved account no longer hyphenates. Decorative symbols stay at default sizes.
Those fixes are5e351cc8, the source of signed1.0(2610071054). Apple accepted the
upload at06:59:22EDT. Internal processing and group assignment remain separate.
No physical-device or complete-parity claim follows from the visual review.
