# Legacy session upgrades and recovery

September 22, 2026. All tests use synthetic accounts and isolated databases. Simulator checks use Xcode 16.4 and iOS 18.6.

## Implemented behavior

Older installed iPhone releases can retain a JWT with an email address but no stable account ID, or an access token without a rotating refresh credential. The new sync engine checks account ownership before sending a mutation. Previously, an email-only JWT could open the account but fail that ownership check, leaving queued changes unsent.

The native transport now upgrades those credentials before bootstrap and account-owned requests. It saves one operation identity before sending the upgrade, keeps it through network errors and malformed responses, and removes it only after Keychain accepts the complete replacement. Existing modern refresh operations migrate to API-scoped storage. Cached account state moves to the replacement credential before rotation so a subsequent outage can still open the same account.

Refresh responses must contain a usable refresh credential and agree with the original account identity. Keychain compares and replaces the credential pair under one lock. An old response cannot overwrite a later sign-in, including when both accounts have refresh requests in flight. Requests for the same saved pair share one renewal. A delayed login also cannot restore an account after sign-out.

The API identifies compatibility upgrades by account, original credential and operation without storing usable access or refresh tokens in mutation acknowledgements. Concurrent retries recover one server session. Revoked upgrades remain revoked. A matching acknowledgement saved by the previous API implementation recovers its original session and is redacted to a session reference when replayed.

Every new session also records the account credential version used to authorize it. A login that checked an old password before a password change cannot later use its refresh credential to obtain access with the new version. Compatibility upgrades recheck the account and original session inside their transaction. Session listings exclude obsolete credential versions.

Browser credentials now retain the compatibility-upgrade operation too. Older envelopes derive one from the existing sign-in identity, so separate tabs choose the same operation. A failed tab observes credential renewal from another tab and retries account loading. This leaves the stable sign-in identity used by unsent drafts unchanged. Storage failures prevent the upgrade request from being sent.

Hosted native unit tests now omit the live application root. They use injected storage, transport and notification cleanup. The earlier host had attempted requests against the developer API while executing unrelated unit tests; the new host avoids opening that account or local store.

## Verification

- Both new native reproduction tests failed before the fix. One could not send an account-owned request after startup; the other changed its operation identity after relaunch. [Original reproduction summary](legacy-sessions/native-reproduction-summary.json).
- All 63 native unit tests pass in `/tmp/exerly-legacy-session-unit-v3.xcresult`. New cases cover cached offline startup, replay, missing or mismatched credentials, failed Keychain writes, failed operation persistence, concurrent renewal, account changes and delayed login after sign-out. Bootstrap, setup acknowledgements and recovery status cannot cache another account's data. [Unit summary](legacy-sessions/native-unit-summary.json).
- The iPhone SE UI journey passes in `/tmp/exerly-legacy-session-ui-v1.xcresult`. A committed compatibility response is lost, the app is terminated, the same operation is recovered on relaunch, an account-owned preference saves, and another offline relaunch opens the cached account. The fixture confirms exactly one recovered upgrade session. [UI summary](legacy-sessions/native-recovery-summary.json).
- All 149 API tests pass on [SQLite](legacy-sessions/api-sqlite.log) and [MongoDB 7.0.24](legacy-sessions/api-mongo.log). New API cases check concurrent upgrade replay, account isolation, storage without usable credentials, revocation and recovery of an acknowledgement from the previous implementation. Two additional [failing reproductions](legacy-sessions/api-version-reproduction.log) verified the password-change race before the credential-version checks were added.
- Both new browser journeys pass in `/tmp/exerly-legacy-session-web-v3.log`. A lost response is replayed across tabs and reload; denied storage blocks transmission until it becomes available. [Browser recovery log](legacy-sessions/browser-recovery.log).
- The full native phase of cross-client v10 passed 72 checks, failed one diary-note assertion and skipped the five browser-return consumers before browser setup. The saved note was below the compact phone's visible area. The test now scrolls before asserting, and its focused rerun passes. [Initial full summary](legacy-sessions/native-full-first-summary.json), [passing diary follow-up](legacy-sessions/native-diary-followup-summary.json).
- Cross-client v11 passes without failures or skips: one browser setup seed, 63 native unit tests and six native producers, all 40 browser journeys, and five native return checks. [Initial native summary](legacy-sessions/cross-client-native-create-summary.json), [browser log](legacy-sessions/cross-client-browser.log), [native return summary](legacy-sessions/cross-client-native-return-summary.json).
- After the final credential-version API change, a fresh fixture passes all 14 standalone browser session journeys and the native legacy-upgrade recovery journey. [Browser regression](legacy-sessions/browser-session-regression.log), [final native recovery](legacy-sessions/native-final-recovery-summary.json). The v11 fixture had already started before that API change, so these follow-ups verify the final server behavior.

The first browser run exposed a tab that stayed on its connection error after another tab renewed the session. The session hook now observes credential changes in addition to sign-in identity. A subsequent run passed the other 13 session journeys but timed out waiting for the background page's accessible content. The focused passing run brings each page to the foreground before checking the recovered UI. The final combined regression also passes this recovery check.

Changed API/browser files pass ESLint and Prettier. The web production build and TypeScript pass with the existing bundle-size warning. SwiftLint using the repository configuration passes with 70 warnings. An initial invocation from the iOS directory omitted that configuration and is not counted as a passing check.

The final unsigned device Release build passes in `/tmp/exerly-legacy-session-release-v3.log` on Xcode 16.4 / SDK 18.5. This verifies compilation, not distribution signing or the required release toolchain.

Apple lists macOS 15.6 or later as compatible with [Xcode 26.2](https://developer.apple.com/xcode/system-requirements), so this Mac's macOS 15.7.9 can run the CI-pinned version. The installer endpoint redirects to Apple's unauthorized page. No installer was found locally or installed, and no authenticated download was attempted. [Toolchain check](legacy-sessions/release-toolchain-check.json).

## Captures

- [Connection error after a lost committed upgrade response](legacy-sessions/legacy-session-upgrade-response-lost.png)
- [Saved preferences after recovering the session](legacy-sessions/legacy-session-upgrade-saved-preferences.png)
- [Cached account after offline relaunch](legacy-sessions/legacy-session-upgrade-offline-relaunch.png)
- [Recovered browser account](legacy-sessions/legacy-session-upgrade-recovered.png)

## Remaining work

Expired legacy credentials still require sign-in. A compatibility acknowledgement from an older deployed API is redacted when replayed; any remaining older credential-bearing operation records need a deployment migration or deletion during account cleanup. No production database was inspected or changed for these tests.

Older session rows without a credential-version field are treated as version zero. Accounts whose password has never changed can retain those sessions. An account with a newer credential version must sign in again to replace an unstamped session. The migration does not remove account drafts or queued writes.

These results do not complete account lifecycle or release acceptance. Browser offline startup, account recovery/deletion, device/session management, broader storage migrations, signed-device checks, staging and beta observation remain in the production plan. The [account calendar audit](calendar-audit.md) tracks the next correctness batch separately.
