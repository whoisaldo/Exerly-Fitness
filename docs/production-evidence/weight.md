# Weight logging verification

September 22, 2026. These checks use synthetic accounts and isolated local APIs.

The API now keeps one revisioned reading per account and calendar day through edits, deletion and explicit restoration. Manual and onboarding readings take precedence over imported readings. The iPhone saves a reading and its pending operation together, replays the same request after a lost response, and requires review of competing edits. Weight history and its trend can render from the owned local records. The browser retains submitted, unacknowledged operations across reloads and exposes retry and conflict review.

Passed checks:

- All 127 API tests on SQLite in `/tmp/exerly-production-weight-api-v1.log` and on an isolated MongoDB 7.0.24 replica set in `/tmp/exerly-production-weight-mongo-v1.log`. New cases cover simultaneous manual edits, response replay, deletion/restore, import precedence, adoption of an old record, account isolation, summary, trend and export.
- All 37 native unit tests and seven standalone UI journeys in `/tmp/exerly-production-weight-native-full-v2.xcresult` on iPhone 16 Pro / iOS 18.6. Weight cases cover disk reopen after a lost response, dependent edits, competing readings, deletion/undo, and reviewed restoration after another device restores and deletes the reading again. The two browser-return consumers are conditionally skipped in the standalone run and run separately against shared browser accounts.
- The shared iPhone → browser → iPhone run in `/tmp/exerly-production-cross-client-v4/` passes both weight and measurement workflows. The native weight producer creates and restores a 73.25 kg reading at revision 5. The browser edits that same record, tests conflicts and replay, then saves 160.50 lb as 72.80 kg at revision 11. A fresh native sign-in verifies the same record and yesterday's separate 74.25 kg reading. All five browser journeys and both native return consumers pass. [Browser edit shown on iPhone](weight-simulator-large/weight-browser-return.png).
- The weight UI journey on iPhone SE 3rd generation with iOS 18.6 in `/tmp/exerly-production-weight-ui-v1.xcresult`. An offline 73.25 kg edit and note survive termination. A competing 75 kg reading requires review. Deleting then undoing the accepted reading preserves its original ID and reaches export. Both Diary and Progress open the saved reading.
- Five browser journeys in `/tmp/exerly-production-weight-web-e2e-v2.log`. The weight journey commits a write then drops its response, reloads, retries the identical operation, reviews a competing edit, deletes/restores, checks separate dates and converts a 160.50 lb entry into 72.80 kg. Existing measurement, diary-status, water and session-isolation journeys pass.
- Web production build in `/tmp/exerly-production-weight-web-build-v2.log`, changed-file ESLint, Prettier and SwiftLint pass. SwiftLint retains style warnings and the web bundle retains its size warning.

The new deletion test exposed an existing local-model fault: `SyncedResource.deleted` could read false after saving a true value. Schema V3 renames that attribute to `tombstoned`. Migration recovers the intended state from the pending queue and saved server payload, while preserving account ownership, record IDs, revisions and immutable requests. An on-disk V2 migration test reopens the upgraded store twice; the original V1 migration test also passes. Apple's [Core Data property-name restrictions](https://developer.apple.com/documentation/coredata/nspropertydescription) explain why framework accessor names must be avoided. The renamed field passes the previously failing deletion test.

The first full native run exposed a test visibility issue after the weight row pushed a food entry farther down the diary. The test now scrolls to that entry. XCTest also left an aborted async test body issuing fixture requests during the following case; allowing async bodies to finish corrected that interference. The first run stalled and was interrupted. The replacement full v2 run passes.

Reviewed iPhone 16 Pro capture: [competing readings](weight-simulator-large/weight-conflict-review.png). Reviewed iPhone SE captures:

- [Offline reading after relaunch](weight-simulator/weight-offline-reopened.png)
- [Competing readings](weight-simulator/weight-conflict-review.png)
- [Deleted reading](weight-simulator/weight-deleted-reading.png)
- [Synchronized undo](weight-simulator/weight-synchronized-undo.png)

Reviewed browser captures: [375 px viewport](weight-web/weight-mobile.png) and [desktop](weight-web/weight-desktop.png).

Compatibility POST/DELETE calls can omit a revision for an old row until a checked client adopts it. Once adopted, all changes require a matching revision. The browser currently retries an unacknowledged weight operation when the user selects Retry; it does not yet provide a full offline application shell. Unsaved form text is not a submitted operation. HealthKit sample reconciliation, physical-device checks and public-release gates remain open in the full production plan.

The later 135-test API suite also passes on both databases after the activity/sleep API additions. Logs are `/tmp/exerly-production-activity-sleep-api-v3.log` and `/tmp/exerly-production-activity-sleep-mongo-v2.log`. All isolated servers from these completed runs have been stopped.
