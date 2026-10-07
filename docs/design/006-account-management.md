# A3: account controls and training sync

App owner, 2026-10-06. Preserve the original purple/pink theme and dark default.

The first internal build exposed a backend mismatch. The replacement now uses
staging and its actual native login/bootstrap is covered by a private synthetic
account smoke test. A3 adds account controls through the same session owner.
It must not create independent refresh implementations for diary and training.
The bridge contract is requested from logic in to-logic.md.

Use Apple's native [SignInWithAppleButton][button] and authorization sheet.
Create a fresh Core nonce and request state for every attempt; consume them once.
Send the identity token, raw nonce and first-authorization name to the shared
account service. Cancellation leaves the email form intact. Show actionable
errors and move VoiceOver focus to them. Use Apple's [black/white styles][style]
for contrast within the existing theme.

Profile opens Account settings. Show connected sign-in methods, a JSON export
share sheet and account deletion. An Apple-only account cannot disconnect its
only sign-in method. Deletion identifies the account, explains the affected data,
requires confirmation and fresh Apple authorization when needed, and returns to
sign-in only after the service confirms deletion and local cleanup. Failure keeps
the account usable. Export must include pending local data or disclose its scope;
server-only export must not claim to include unsynced workouts.

Training gets the account-bound DocumentAPI from the shared session owner, with
cancellation/quiescence before sign-out or deletion. Logging never waits for sync.
Settings shows the last successful sync and a retry action; offline and expired
sessions have distinct messages. Recreate stores on account change.

The first UI files can compile against injected actions while logic publishes
the bridge. Do not expose unconnected controls in a release. Hosted tests cover
nonce/state handling and account-action presentation. Simulator journeys must
cover cancel/error/success, destructive confirmation, export and account switching.
Actual Apple authorization needs a signed device; never claim a stub verifies it.

## Prepared UI evidence, 2026-10-06

Three hosted presentation tests cover nonce/state matching and protected export
files. Two synthetic account UI journeys cover destructive confirmation,
cancellation, a failed delete preserving the account, and preventing an
Apple-only account from disconnecting Apple. Both pass at the largest Dynamic
Type size in light/dark on SE3 (iOS18.6) and 17ProMax (iOS26.2). All screenshots
were inspected. Native alerts keep an explicit Cancel action on both OS versions.
Results are under `artifacts/account/` in the app-next worktree:
`presentation`, `controls`, `small-light-fixed`, `large-dark-fixed`,
`small-dark-final` and `large-light-final` xcresults.

The Exerly bundle now has Apple's primary-app sign-in capability. Profile
J5J395Y9AF contains both HealthKit and Sign in with Apple, using the existing
certificate. Archive/IPA2610061727 passed signing validation but was not uploaded;
it predates the final alert changes. TestFlight remains2610061654. These checks
do not verify real Apple authorization, export or deletion. The shared bridge
landed next and must be connected and tested before this milestone ships.

[button]: https://developer.apple.com/documentation/authenticationservices/signinwithapplebutton
[style]: https://developer.apple.com/documentation/authenticationservices/signinwithapplebutton/style
