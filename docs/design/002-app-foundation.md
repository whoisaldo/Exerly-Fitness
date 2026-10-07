# App foundation and internal releases

2026-10-06. App agent milestone A1.

Create a sourced, testable inventory before changing the user experience. Existing
screens and historical screenshots count as implementation evidence only. A parity
row passes after its acceptance criteria run on current device builds, including
an internal TestFlight build. Keep Beyond promises measurable and label competitor
claims from public primary sources.

Establish a fresh Xcode 26.2 baseline in this worktree. Use dedicated Exerly App
simulators, a large iPhone on iOS 26.2 and a small iPhone SE on iOS 18.6. Save raw
logs and xcresult bundles under ignored artifacts/app-baseline. Record failures
without attributing them to changes that have not happened yet.

Release tooling belongs under apps/ios/scripts. It must reuse the authorized
distribution certificate, isolate signing in a temporary keychain, register only
Exerly identifiers and capabilities, and use timestamp build numbers. It must
validate the archived app's identity, privacy manifest, icons, entitlements and
version before upload. Internal distribution is limited to Ali. External review
and App Review remain separate decisions.

Tests cover release checks with synthetic fixtures before implementing tooling.
Run the current API suite, native unit/UI tests and unsigned device build before
landing. A successful upload and a processed, installable TestFlight build are
separate recorded results.

Next milestone A2 replaces the app shell and adds training using the published
ExerlyCore interface. Request contracts before building. Do not put domain maths,
network calls or a second persistence implementation into new screens.
