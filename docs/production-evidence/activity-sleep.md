# Activity and manual sleep verification

Activity and sleep use account-owned records with stable identities, revisions, deletion markers and explicit restoration. The native app queues submitted changes in SwiftData. Browser drafts, pending operations and cached records are scoped to the account and API environment. A retry keeps the original operation identity and body; applying a reviewed conflict creates a new operation.

Activity duration retains fractional minutes. Calories remain unknown when blank and retain an explicit zero. Sleep quality is optional. Overnight sleep belongs to its wake date, and naps are separate records. The diary sums every active sleep entry. Optional clock times do not calculate duration or reconcile overlaps.

## Passed checks

- 136 API tests on SQLite in `/tmp/exerly-production-activity-sleep-api-v4.log` and MongoDB 7.0.24 in `/tmp/exerly-production-activity-sleep-mongo-v3.log`. Coverage includes simultaneous writes, operation replay, revision conflicts, ownership, legacy adoption, soft deletion, restoration, resets, unknown values, fractional durations, multiple sleep entries, date isolation and export.
- Seven standalone browser journeys in `/tmp/exerly-production-activity-sleep-web-v3.log`. The activity and sleep journeys recover drafts after reload, lose a committed response, retry the identical operation, review a competing edit, delete and restore the same record, preserve unknown values, and follow a record moved to another date. The native-return browser journey is conditionally skipped here.
- The browser account-isolation check in `/tmp/exerly-production-activity-sleep-account-web-v2.log`. It holds a successful activity response across sign-out and a second sign-in. The second account stays empty; returning to the original account shows its single synchronized entry.
- Web production build in `/tmp/exerly-production-activity-sleep-build-v4.log`. The existing bundle-size warning remains.
- All 42 native unit tests in `/tmp/exerly-production-activity-sleep-unit-v5.xcresult` on iPhone SE / iOS 18.6. New coverage includes on-disk reopen, normalized server identities, unchanged replay payloads, dependent edits, conflicts, delete/undo, account isolation, a previously uncached day, remote date moves/deletions and localized decimal validation.
- The activity/sleep UI journey passes on iPhone 16 Pro / iOS 18.6 in `/tmp/exerly-production-cross-client-v5/native-create.xcresult`. It saves a fractional activity, overnight sleep and a nap three days earlier while offline; reopens the entries; rejects malformed numeric input; synchronizes; reviews a competing activity edit; deletes and undoes both record types; and checks date isolation and export. The containing full run also had an incorrect Arabic-locale unit fixture; that fixture was corrected and all 42 unit tests passed separately above. Do not report the containing run as an overall pass.

All eight standalone iPhone 16 Pro UI journeys pass in the v5 bundle, with the separate unit-fixture limitation described above. `/tmp/exerly-production-cross-client-v6/native-create.xcresult` passes all 42 unit tests and three recovery UI journeys on iPhone SE, third generation, iOS 18.6. Its browser phase passes eight journeys but fails the new sleep round trip because an exact-label selector does not find the dropdown. That selector now uses the dropdown's accessible role and name. The corrected shared native/browser/native run passes in `/tmp/exerly-production-cross-client-v7/`: 42 unit tests and three native recovery producers, all 20 browser journeys, then all three native return consumers. There are no failed or skipped tests in this shared run. All native phases use iPhone SE, third generation, iOS 18.6. Earlier attempts exposed shared list-button actions, an offscreen XCTest query, date arrows firing together, uppercase local UUIDs duplicating lowercase server identities, and partially accepted malformed decimal text. These failures are not passing evidence.

Browser history supports 7, 30 and 90 days. Sleep averages divide the total across days containing saved sleep, including naps; missing days are excluded. The history/date-move checks pass in `/tmp/exerly-production-activity-sleep-history-web-v1.log`.

## Shared record results

The iPhone creates the records, reopens them offline, resolves a competing activity edit and checks deletion/undo. The browser then edits the same activity from 45.5 to 63.25 minutes and clears its recorded calories, reaching revision 6. It replays a lost acknowledgement with the identical operation and body. The main sleep entry changes from 8.25 to 8.75 hours with quality set to good, reaching revision 5; the separate 0.5-hour nap remains unchanged. The new native session reads those same IDs, clock times and values. Both clients and export agree on 9.25 hours for the selected day.

Retained summaries for the shared run: [native producers](cross-client-v7/native-create-summary.json), [native return checks](cross-client-v7/native-return-summary.json), and [browser results](cross-client-v7/browser.log). The original XCTest bundles remain at the temporary paths above.

## Simulator captures

The following captures were exported from XCTest and visually inspected. Standard text sizes fit both screen widths, including the selected wake date and optional clock times.

- [iPhone SE activity form](activity-sleep-simulator-small/activity-offline-reopened.png)
- [iPhone SE sleep form](activity-sleep-simulator-small/sleep-offline-reopened.png)
- [iPhone SE conflict review](activity-sleep-simulator-small/activity-conflict-review.png)
- [iPhone 16 Pro activity form](activity-sleep-simulator-large/activity-offline-reopened.png)
- [iPhone 16 Pro sleep form](activity-sleep-simulator-large/sleep-offline-reopened.png)
- [Browser activity edit returned to iPhone SE](activity-sleep-simulator-small/activity-browser-return.png)
- [Browser sleep edit returned to iPhone SE](activity-sleep-simulator-small/sleep-browser-return.png)

## Browser captures

- [Activity on a small screen](activity-sleep-web/activity-mobile.png)
- [Sleep on a small screen](activity-sleep-web/sleep-mobile.png)
- [Reviewing an activity conflict](activity-sleep-web/activity-conflict.png)
- [Reviewing a sleep conflict](activity-sleep-web/sleep-conflict.png)
- [Shared native records after browser editing](activity-sleep-web/sleep-native-browser.png)

## Remaining scope

The browser requires its application and authenticated session to load; a complete offline application shell is still pending. Pending browser changes retry when the user chooses Retry. Native unsaved activity/sleep form text is not a submitted operation. Imported sleep intervals, source precedence, overlap reconciliation, daylight-saving handling and HealthKit belong to the remaining health work. Physical-device and public-release gates remain open in the full production plan.
