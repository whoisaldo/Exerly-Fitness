# Native account calendar

September 22, 2026. All accounts and API fixtures in these checks are isolated test data.

Native diary, food, activity, sleep, weight and measurement flows now carry strict Gregorian calendar days. Today comes from the account's saved time zone. Pickers and chart labels use a UTC anchor only for display, so changing the device zone cannot move a stored day. Foregrounding and a periodic clock refresh update Today without rewriting an open form or a queued operation.

The original native reproduction put the account and simulator on different dates. The phone selected its device day, and its water addition did not reach the account's Today. The fixed UI journey now agrees with the API, adds 250 ml to the correct day and retains that day after relaunch.

Legacy device measurements contain timestamps without their original time zone. Import now shows the original timestamp and an editable proposed calendar day for every selected record. The reviewed day stays fixed if account preferences change. Import checks that the original records still match the review before atomically queuing them; an intervening edit preserves the originals and rejects the stale review.

## Evidence

- [Initial failing native reproduction](calendar-native/reproduction-summary.json), from `/tmp/exerly-native-calendar-red-v1.xcresult`.
- [67 passing unit checks](calendar-native/unit-summary.json), from `/tmp/exerly-native-calendar-unit-v4.xcresult`, iPhone 16 Pro simulator, iOS 18.6. Coverage includes strict date decoding, leap days, year boundaries, DST, the skipped Apia date, account changes, offline reopening and reviewed legacy import. A single test queues all seven daily mutation types, changes the account time zone, and verifies their operation IDs and payload bytes are unchanged.
- The focused native reproduction passes in `/tmp/exerly-native-calendar-green-v1.xcresult`. Its [account-day capture](calendar-native/attachments/50A657DC-DE3C-4E80-A0CC-25C3D9083431.png) shows the resulting diary on iPhone SE.
- [Full native UI regression](calendar-native/ui-summary.json), from `/tmp/exerly-native-calendar-ui-all-v1.xcresult`, iPhone SE, iOS 18.6. Twelve checks pass, six conditional cross-client checks skip, and none fail. This run started before the separate opt-in video capture test was added.
- The unsigned device Release build passes in `/tmp/exerly-native-calendar-unsigned-release-v1.log`. The public-release toolchain gate correctly fails in `/tmp/exerly-native-calendar-release-v1.log`, because this machine has Xcode 16.4 and SDK 18.5.
- SwiftLint passes with 71 warnings and no serious violations in `/tmp/exerly-native-calendar-swiftlint-v2.log`, with `DEVELOPER_DIR` set to the installed Xcode. Running it against the machine's command-line-tools selection could not load SourceKit; that environmental failure is retained in the preceding log.

The combined browser/iPhone/browser/iPhone run also passes in `artifacts/calendar-cross-client-v12`: one browser setup seed, 67 native unit tests and six initial native UI journeys, all 46 browser journeys, then five native return journeys. There are no failures or skips. [Native creation summary](calendar-native/cross-client-create-summary.json), [browser log](calendar-native/cross-client-browser.log), and [native return summary](calendar-native/cross-client-return-summary.json) retain the results.

## Remaining coverage

Further boundary journeys should exercise previous-day sheets, scanning across midnight, and time-zone changes while native forms are open. HealthKit's existing Today readout and the unused legacy streak service still use the device calendar; the full health-import work remains open. Physical-device, staging, beta and public-release gates remain open in the production ledger.
