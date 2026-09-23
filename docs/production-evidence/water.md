# Water logging verification

September 22, 2026. Synthetic accounts and isolated fixture APIs. Native tests use Xcode 16.4 and the iPhone SE, third generation, on iOS 18.6. Browser tests use installed Chrome through Playwright.

Water additions now persist before sending. The iPhone writes its local day and operation together in SwiftData. The browser stores each addition under a separate account, API environment, date and operation key. Separate keys prevent another tab from replacing an unacknowledged addition. Retries preserve the operation identity and body. Both clients expose a retry path and preserve the chosen date.

The API applies additions in the same transaction as their acknowledgement. It emits a versioned day total in the change feed. An old acknowledgement does not replace a newer server total. Native queued additions are rebased after acknowledgement; the browser lists amounts awaiting confirmation separately from the recorded total.

Passing checks:

- 124 API tests on SQLite and an isolated MongoDB replica set, including eight concurrent additions, replay after later additions, revision-checked corrections, nonnegative totals, date/account isolation, summary and export.
- 32 native unit tests in `/tmp/exerly-production-water-unit-v2.xcresult`. The added test closes and reopens the on-disk store, replays a lost acknowledgement before a later addition, and retains water logged by a different device. The final 1,050 ml is 250 + 500 + 300, with no duplicate.
- The final water UI journey in `/tmp/exerly-production-water-ui-v6.xcresult`. The app starts from 100 ml yesterday, saves 250 + 500 ml offline, relaunches with 850 ml, then merges a separate 300 ml and displays 1,150 ml. Today stays at zero and export matches.
- Four browser journeys in `/tmp/exerly-production-water-web-e2e-v3.log`, including water response loss/reload/replay, custom amount entry, previous-day logging, simultaneous offline additions in two tabs, and API/export agreement. Both tabs preserve their operations and converge on 1,800 ml after retry. Existing measurement, diary-status and session-switch journeys stay passing.
- Web production build and changed-file ESLint passed. SwiftLint passes with warnings using the repository-root configuration. An earlier invocation from `apps/ios` used default rules and failed; it is not the configured lint result.

Screenshots are saved in [water-simulator](water-simulator/) and [water-web](water-web/). The first native captures exposed wrapped labels in the three-button row on the SE. The updated layout puts custom entry on its own row. `/tmp/exerly-production-water-ui-v2.xcresult` passed both water and diary-status journeys after this change. It also checks rejection of 5,001 ml before saving a valid 500 ml. The current native captures come from the final v6 run and were inspected on the SE. The custom amount form keeps units visible and clears its validation message when the amount changes.

This completes positive water additions and retry/recovery in the tested flows. Per-addition history, editing or undoing an individual addition, reminder scheduling, HealthKit imports and a full offline browser shell remain. Absolute API corrections support revisions, but older installed clients can still submit an unversioned absolute total for compatibility.

The two-tab expansion initially failed in `water-web-e2e-v2`. It exposed a session-refresh loop, with 5,086 refresh requests in the captured trace before the timeout. An already validated tab now reads `/api/me` after a shared token change instead of issuing another session. The passing v3 test limits refreshes across its reloads and tabs to five, and the prior delayed-response account-switch regression still passes.

Native UI runs v3 and v5 failed because the test helper inserted text before a right-aligned amount instead of replacing it. The app correctly rejected that out-of-range input. A global caret adjustment affected an onboarding field, so run v4 was interrupted and that adjustment was removed. The final form uses an ordinary field with a persistent label. The test helper also checks the exact entered value. Run v6 passed; the failed and interrupted runs are not passing evidence.

The API now also limits compatibility refresh to 60 requests per account per ten minutes. `/tmp/exerly-production-water-sqlite-v4.log` and `/tmp/exerly-production-water-mongo-v3.log` pass all 124 API tests, including a regression proving that user reads create no sessions and excess refreshes cannot grow the session table. Another account remains unaffected.

The final API suite also verifies that an existing unversioned water row keeps its ID and 875 ml balance, then advances to 1,125 ml at revision 2 after a 250 ml addition. Its account ID is filled in without creating a second row.

The final complete native run, `/tmp/exerly-production-water-native-full-v1.xcresult`, passed 32 unit tests and all six standalone UI journeys on iPhone 16 Pro / iOS 18.6. The conditional browser-return consumer was skipped because this fixture does not run the combined measurement sequence. That consumer passed separately in the earlier cross-client run. This final run includes the exact-value input assertion and the new water controls alongside signup, interrupted setup, offline food edits, legacy repair, measurements and diary status.

Larger-iPhone water captures are saved in [water-simulator-large](water-simulator-large/). All test servers from this batch are stopped after their checks.
