# Browser session verification

September 22, 2026. Headless Chrome with an isolated API and synthetic accounts.

## Rotating credentials and recovery

Both clients now use the API's modern session protocol. Browser access tokens last 15 minutes. The refresh credential, its next operation identity and the access token are stored together under the configured API URL. Refreshing preserves a browser sign-in identity; signing out or signing in changes it. Same-tab consumers share a pending refresh, and simultaneous tabs send the same saved credential and operation. A response from an earlier account or an older rotation cannot replace the current session.

Authenticated requests share one transport, including the older dashboard, profile, admin and coach screens. An access rejection can trigger one refresh and one replay with the original request body and mutation identity. Network failures do not automatically replay mutations. A rejected password confirmation does not discard a valid session. Fresh launches read the account without creating another server session.

Sign-out clears the current environment's credentials immediately and revokes the captured server session. It can renew an expired access token for that revocation without storing the result. If the server cannot be reached, the public page says that revocation was not confirmed. Other environment credentials and account-owned pending logs remain separate.

The sign-in form has visible labels, password-manager autocomplete, a bounded request, disabled repeated submission, and cancellation when leaving the page. A generation marker also catches another tab signing in and then signing out while an anonymous login response is pending. The older placeholder password-recovery link is removed until the recovery workflow exists.

### Current evidence

- `/tmp/exerly-production-modern-session-web-v3.log` passes 16 standalone browser journeys with one conditional native-account consumer skipped. It includes concurrent refresh from two tabs, committed refresh response loss and reload, an unchanged water write retried after access rejection, remote revocation, logout, API environment isolation, one-time scoped legacy upgrade, wrong password confirmation, abandoned sign-in and delayed old-account responses. Existing activity, sleep, water, weight, measurement and diary-status recovery journeys remain green.
- `/tmp/exerly-production-modern-session-signup-v1.log` passes two additional checks. A double-click creates one browser signup session and opens unfinished setup with no invented targets. Another tab's sign-in followed by sign-out invalidates an earlier anonymous login response. The latter also checks a 375-pixel layout.
- The production web build passes in `/tmp/exerly-production-modern-session-build-v4.log`, including TypeScript. The existing bundle-size warning remains. Full web ESLint passes in `/tmp/exerly-production-modern-session-lint-v5.log` with 33 existing warnings. The complete web Prettier check passes in `/tmp/exerly-production-modern-session-format-check-v3.log`.
- All 20 browser journeys pass in `/tmp/exerly-production-cross-client-v7/browser.log`, including the shared native-account edits. The iPhone SE producer phase passes 42 unit tests and three UI journeys. All three native return consumers also pass on iPhone SE / iOS 18.6. The complete shared run has no failures or skips.
- `/tmp/exerly-production-modern-session-storage-v1.log` separately passes malformed refresh JSON followed by a failed credential-storage write. Reload and retry keep the original credential and operation through both failures. This check also passes in the 20-journey browser run.

The first new run passed five session checks but failed a test's final activity label. The second run exposed a real route-transition race: effect cleanup could happen after a late login response. Cancellation on navigation, a route check and the authentication generation marker fix that race. The passing runs above supersede those failures.

Retained summaries for the shared run: [native producers](cross-client-v7/native-create-summary.json), [native return checks](cross-client-v7/native-return-summary.json), and [browser results](cross-client-v7/browser.log). The original XCTest bundles remain at the temporary paths above.

### Captures

- [Session refresh interrupted after commit](browser-modern-sessions/refresh-response-lost.png)
- [Saved activity after session recovery](browser-modern-sessions/draft-after-session-recovery.png)
- [Account change while signing in on a small screen](browser-modern-sessions/login-account-change-mobile.png)

### Remaining scope

Refresh credentials are held in the browser's origin storage, which is accessible to scripts on that origin. This does not establish a cookie-based, HttpOnly session boundary or deployment-level script isolation. Public-release security review and deployment hardening remain open. Browser offline startup, recovery email, verification, and a user-facing session-management screen remain unfinished. [Setup draft parity](setup-parity.md) is now implemented and verified in the later cross-client run.

## Earlier compatibility-session checks

The browser's previous refresh handler could write credentials after its component unmounted. A response from a signed-out account could therefore replace the credentials saved by a later login. Session consumers also shared an unscoped cached user and could issue duplicate refresh requests.

At that stage, the session hook keyed its cached user and pending request to the current credential. Consumers share one request. Before adopting a response, it verifies the credential and session generation still match. Same-tab credential updates and cross-tab storage events update consumers, and a new credential hides the previous user's state immediately.

`/tmp/exerly-production-web-session-e2e-v2.log` passed three journeys. The session case creates two accounts with different waist measurements, holds the first account's successful refresh response, signs out, and signs into the second account. Releasing the old response leaves the second credential and its 76.5 cm measurement unchanged. The test observes exactly two refresh calls, one per account. The first account's 88.25 cm value does not appear.

The same run covers body-measurement synchronization and diary status persistence, conflict review, immutable replay, and switching days while the next summary response is delayed. Selecting yesterday removes today's status controls before that response arrives; editing yesterday leaves today's revision unchanged.

TypeScript and the production web build passed in `/tmp/exerly-production-web-session-build-v1.log`. ESLint and Prettier passed in `lint-v13` and `format-v6`; the existing warnings remain documented in the delivery ledger.

That batch fixed account isolation for the compatibility session flow. Modern rotation and cross-tab coordination were completed in the later batch above. Durable offline browser reads remain unfinished.

## Two-tab recovery regression

The water workflow added a simultaneous two-tab test. Its first run exposed a refresh loop because each tab issued a new session after the other tab changed the shared token. The captured failure issued 5,086 refresh requests before timing out. Once a tab has a validated session, it now uses `/api/me` to resolve a changed credential without creating another session. Initial launches still used the compatibility refresh endpoint at that stage.

`/tmp/exerly-production-water-web-e2e-v3.log` passes all four browser journeys, including the old delayed-response account-switch regression and the new two-tab water recovery. The latter asserts at most five refresh requests across login, reloads and both tabs. That batch fixed the loop. The later rotating-session batch above replaces compatibility refresh on modern launches.

The compatibility refresh endpoint is additionally limited to 60 requests per account per ten minutes. The 123-test SQLite and MongoDB runs cover the limit and verify that `/api/me` creates no new sessions.
