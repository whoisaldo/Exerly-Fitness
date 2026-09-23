# Profile preferences and local reminders

September 22, 2026. Tests use synthetic accounts, the real API, isolated SQLite and MongoDB databases, and iOS 18.6 simulators with Xcode 16.4.

## Implemented behavior

Both clients can edit profile details, food preferences, allergies, meal count, training experience, equipment, preferred activities, workout days, sleep goals and times, display units, time zone, and reminder intent after setup. The iPhone form keeps optional sections collapsed until opened. Profile links lead to the editor on both clients.

The versioned `/api/preferences` contract returns the current account revision. Patches require that revision and a persisted operation identity. A replay returns the original acknowledgement; clients then read the current account so a later device edit survives. Conflicts display the edited fields and the saved account values. A reviewed replacement changes only the edited fields, including individual reminder choices. Another server change during review requires another review.

Drafts belong to the account and API environment. Browser tabs retain separate drafts. Both clients preserve raw invalid input across relaunch, retain unreadable drafts, and stop uploads when local persistence fails. Unconfirmed submissions stay immutable until replay or conflict resolution. Responses from a previous sign-in cannot update the current account.

Height conversions retain canonical centimeters through repeated unit changes. Editing preferences never rounds or re-saves weight, creates a weigh-in, or rewrites accepted nutrition targets. Sleep and weekly workout goals update atomically with the preferences. Older profile, settings and goal endpoints increment the same preference revision. MongoDB now retains empty JSON objects, including those inside stored mutation responses, so replay matches the original response and SQLite behavior.

Local iPhone notifications use saved meal times, selected workout weekdays, and a sleep reminder time. Times use the saved account time zone. Missing times produce an explanation without inventing a schedule. Reminder intent is shared, while delivery is enabled separately for each account on each iPhone. Permission is requested only through the explicit enable action. Denial retains intent; disabling delivery or signing out removes owned pending requests. Serial scheduling and credential checks prevent an old task from restoring another account's reminders.

The app checks OS permission on return to the foreground before waiting for the preferences API. It uses saved preferences during an outage and exposes refresh errors. Preferences from another device apply when the app next connects. A scheduling error stays visible and preserves the saved choices. The implementation follows Apple's documentation for [contextual notification permission](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications) and [calendar triggers](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger).

## Verification

| Check                                 | Result                                                                                                                                       | Evidence                                                                                                                                                                                        |
| ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Full SQLite API suite                 | 144 passed, no failures or skips                                                                                                             | [SQLite log](preferences/api-sqlite.log)                                                                                                                                                        |
| Full MongoDB 7.0.24 replica-set suite | 144 passed, no failures or skips                                                                                                             | [MongoDB log](preferences/api-mongo.log)                                                                                                                                                        |
| Browser preference journeys           | Eight passed across two runs                                                                                                                 | [First six](preferences/browser-first-six.log), [account change and refresh race](preferences/browser-account-and-refresh.log)                                                                  |
| Final native unit regression          | 54 passed, including a closed editor retaining a reopened editor's newer draft                                                               | [Summary](preferences/native-final-unit-summary.json)                                                                                                                                           |
| Native units and OS scheduling        | 53 unit tests and one UI journey passed on iPhone 16 Pro, no failures or skips                                                               | [Summary](preferences/native-unit-and-scheduling-summary.json)                                                                                                                                  |
| Native background delivery            | iOS displayed the scheduled reminder while Exerly was backgrounded; cancellation and relaunch passed                                         | [Summary](preferences/native-delivery-summary.json)                                                                                                                                             |
| Shared iPhone/browser/iPhone run      | One browser seed, 53 native unit tests and five UI producers, all 38 browser journeys, then five native return journeys passed with no skips | [Native producers](preferences/cross-client-native-create-summary.json), [browser](preferences/cross-client-browser.log), [native returns](preferences/cross-client-native-return-summary.json) |
| Final native editor regression        | The final editor lifecycle implementation passes the SE draft, lost-response and conflict journey                                            | [Summary](preferences/native-final-editor-summary.json)                                                                                                                                         |
| Native editor on iPhone SE            | Draft recovery, unit changes, lost response, another device's edit and conflict review passed                                                | `/tmp/exerly-preferences-native-ui-v1.xcresult`                                                                                                                                                 |

The shared run in `/tmp/exerly-production-cross-client-v9/` uses iPhone SE, iOS 18.6. It confirms that browser edits to profile and reminder intent return to the iPhone and survive relaunch. Existing setup, measurement, weight, activity and sleep round trips still pass. The separate final unit run adds the closed-editor regression after the shared run's initial native phase.

The browser checks exercise every editor field, reload, decimal input, repeated unit conversion, two tabs, reviewed conflicts, a save waiting on an in-flight refresh, lost acknowledgements, later device writes, account changes, unavailable storage and unreadable drafts. Export retains the same program and weight history.

Native tests cover the same ownership and replay boundaries, including a second server edit during conflict review. Reminder tests verify saved time zones, weekdays, missing schedules, denied permission, relaunch, scheduling errors, unrelated notification preservation, sign-out and an account change during an in-flight add.

The first MongoDB run exposed Mongoose's removal of empty objects from saved acknowledgements. The passing run includes the storage fix. An early unit run also exposed a test teardown issue: a logout request outlived its mock handler. The final 54-unit-test run passes without that crash. Its additional lifecycle case verifies that a dismissed editor cannot overwrite a newer draft after its save response arrives.

The simulator displays a real local reminder while Exerly is in the background and retains the delivery setting across relaunch. Its Settings app opens without a notification settings pane, so the initial UI test that tried to revoke permission through Settings failed. Denied-permission behavior is covered through the native scheduler tests. The simulator UI test now checks the OS behavior available in this runtime instead of claiming Settings coverage.

## Captures

- [Browser editor at desktop width](preferences/preferences-desktop.png)
- [Browser editor at 375 pixels](preferences/preferences-mobile.png)
- [Browser conflict review at 375 pixels](preferences/preferences-conflict-mobile.png)
- [Native preferences opened in the browser](preferences/preferences-native-to-browser.png)
- [Browser preferences returned to iPhone SE](preferences/preferences-browser-to-native.png)
- [Shared reminder intent on iPhone SE](preferences/preferences-shared-reminder-intent.png)
- [Food preference draft on iPhone SE](preferences/preferences-native-food-draft.png)
- [Native draft reopened](preferences/preferences-native-draft-reopened.png)
- [Native conflict review](preferences/preferences-native-conflict.png)
- [Saved fractional sleep goal](preferences/preferences-native-saved-sleep.png)
- [Reminder displayed by iOS while Exerly is in the background](preferences/reminder-delivered-by-ios.png)
- [Reminder scheduled on this iPhone](preferences/reminder-device-scheduled.png)
- [Delivery disabled on this iPhone](preferences/reminder-device-disabled.png)

## Remaining work

This batch does not complete reminders or the broader production plan. Quiet hours, notification deep links, more DST cases, and physical-device permission changes remain. Food and training personalization must also reach the remaining meal-planning and structured-training workflows. Notification changes made elsewhere require the iPhone to reconnect; there is no server push to refresh a closed app.

Browser offline startup, wider legacy migrations, accessibility/device coverage, account lifecycle, release toolchain, staging, operations and beta observation remain in the delivery ledger. The local SDK and simulator checks do not establish App Store readiness.
