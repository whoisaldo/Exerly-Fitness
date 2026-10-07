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

| Area                 | Existing routes                                                                      | State                                                                                       |
| -------------------- | ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------- |
| Diary                | Daily summary, populated/empty meals, date, status, notes, copy, undo                | Summary, compact status/actions and guarded editors implemented; captures under review      |
| Food                 | Picker, search, barcode, label editor, amount editor, saved library/detail           | Shared label/portion/keypad and library/repeat hierarchy implemented; full journeys running |
| Training             | Home, active workout, set editor, notes, rest timer, exercise picker/detail          | Session summary, prior/RIR rows and keypad implemented; final visual review pending         |
| Programs             | List/detail, builder/day/slot targets, overrides, planned workout, lifecycle reviews | Implemented; final light/dark and accessibility review pending                              |
| History and insights | History/detail, exercise logs, observations, source-set links                        | Implemented; final light/dark and accessibility review pending                              |
| Agents               | Inbox, proposal review/diffs/evidence/audit, tokens/create/revoke                    | Implemented; final light/dark and accessibility review pending                              |
| Progress             | Measurements, weight/chart/history/edit/conflicts, photos, achievements              | Implemented; final light/dark and accessibility review pending                              |
| Account              | Profile, preferences, appearance, password, account export/delete, sync, Health      | Implemented; final light/dark and accessibility review pending                              |
| Daily health         | Activity/sleep/water summaries and editors, conflict/undo                            | Implemented; final light/dark and accessibility review pending                              |
| First run            | Welcome, email/Apple login, signup, setup/repair/results                             | Pending visual review                                                                       |

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
