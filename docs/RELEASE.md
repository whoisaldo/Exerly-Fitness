# Exerly release readiness

Updated 2026-10-06. Internal TestFlight is authorized. External TestFlight and App
Review require Ali's decision after the build and review material are ready.

## Current build

Version 1.0, build 2610061616. Signed archive and IPA exported successfully with
Xcode 26.2 and the iOS 26.2 SDK. Archive identity, HealthKit entitlement, profile,
privacy manifest, icon, version and absence of debug fixture hooks passed the
release validator. No upload or physical-device install has occurred.

- Archive: `apps/ios/build/release/2610061616/Exerly.xcarchive`
- IPA: `apps/ios/build/release/2610061616/export/Exerly.ipa`
- Logs: `apps/ios/build/release/2610061616/{archive,export}.log`
- Bundle: `com.exerly.fitness`, Apple bundle resource `UJ5X8TJKNL`.
- Team: `9X79V37Q89`. Reused distribution certificate, expires 2027-09-25.
- Exerly profile: `H5896RXW3D`, expires 2027-09-25. HealthKit enabled.
- App Store Connect: Exerly, app ID `6819776832`, created through the website.
- Internal group: `Exerly Internal · Ali`, `c5ae1d39-0fe4-4bee-af89-0374d9519afe`; only Ali, no public link or automatic future builds.

Build and signing outputs are ignored. Keys, certificate material, passwords and
profiles stay outside the repository. No other app's identifiers or profiles changed.

## Repeatable commands

From the repository root:

```sh
python3 -m unittest discover -s apps/ios/scripts/tests
node --test apps/ios/scripts/tests/asc.test.mjs
node apps/ios/scripts/asc.mjs provision
bash apps/ios/scripts/release.sh --dry-run
bash apps/ios/scripts/release.sh --archive
bash apps/ios/scripts/release.sh --upload
node apps/ios/scripts/asc.mjs status
node apps/ios/scripts/asc.mjs internal BUILD_NUMBER
```

Use a new UTC timestamp for each archive. `BUILD` can override the default
`yymmddHHMM`. The script refuses to overwrite an archive. Signed modes use a
temporary keychain, restore the prior keychain list and remove only the profile
they installed. `--archive` produces a signed IPA without an upload. `--upload`
exports for internal testing only, checks that the app record exists, then uploads.
Run `internal BUILD_NUMBER` only after Apple reports the build as valid. It checks
that the existing tester is Ali and internal, and that the group has no public
link, no other members and no automatic access to future builds.

The [initial app record][apps] and Ali's membership in the internal group were
created through Apple's website. API checks verify the group and account-holder
email before assigning a build. Apple's [inviteType][invite] describes email
versus a public link; internal status comes from the group's isInternalGroup.
Manual profile selection is scoped to the app target so Swift package resource
bundles are not given an unsupported provisioning profile.

## App Store checklist

| Item                              | State                 | Acceptance and next action                                                                                                                             |
| --------------------------------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Bundle registration               | Done                  | Only com.exerly.fitness registered; HealthKit enabled.                                                                                                 |
| Distribution signing              | Done                  | Existing certificate reused; signed archive and export verified.                                                                                       |
| App icon                          | Built                 | Original 1024px opaque monogram; inspect installed home-screen appearance.                                                                             |
| App Store Connect record          | Done                  | Exerly created, app ID 6819776832.                                                                                             |
| Internal group                    | Done                  | Exerly Internal · Ali; only account-holder Ali, no public link, explicit builds.                                                                                                  |
| Internal TestFlight upload        | Pending upload        | Upload, poll processing, assign build, verify install.                                                                                                 |
| Feature parity                    | Open                  | Every PARITY.md row must have device evidence.                                                                                                         |
| Beyond                            | Open                  | Ship and measure B01-B12; no unproven superiority claims.                                                                                              |
| Native test suite                 | In progress           | 72 unit tests and 14 native UI journeys pass; 7 cross-client tests opt-in. Rebased rerun pending.                                                                                     |
| Light/dark and Dynamic Type       | Open                  | Inspect all major flows at largest text on small/large phones.                                                                                         |
| VoiceOver/contrast/reduced motion | Open                  | Device audit, accessible form errors and charts, no clipped controls.                                                                                  |
| Performance                       | Open                  | Cold-launch measurements and 60 fps scrolling traces on a physical phone.                                                                              |
| Offline and conflict behavior     | Partial               | Existing queue tests pass; every new domain needs equivalent device journeys.                                                                          |
| Sign in with Apple                | Open                  | Logic contract plus native button, nonce and error flow.                                                                                               |
| Account deletion                  | Open                  | Reauthentication, confirmation, server deletion and local cleanup.                                                                                     |
| Export/import                     | Partial               | Full-fidelity export/import with user review and synthetic round-trip fixtures.                                                                        |
| Production database               | Blocked on deployment | Ali supplies Neon/DO secrets; logic owns migration and backups.                                                                                        |
| Privacy manifest                  | Built                 | UserDefaults reason CA92.1; account, health, fitness and user content for functionality; no tracking. Audit before submission.                         |
| Privacy labels                    | Draft                 | Match actual server/cloud handling. Do not publish until the final data-flow audit.                                                                    |
| Privacy policy                    | Open, Ali review      | Plain-language retention/deletion, HealthKit, provider disclosures and cloud opt-in; needs hosted URL.                                                 |
| HealthKit purpose strings         | Partial               | Capability/signing fixed; final type-by-type permission/consent audit remains.                                                                         |
| Cloud inference consent           | Open                  | Existing Gemini feature requires disclosure/opt-in redesign before public release.                                                                     |
| Encryption/export compliance      | Draft                 | App uses platform TLS/Keychain, no custom encryption; Info declares no non-exempt encryption. Ali reviews legal declarations before public submission. |
| Age rating                        | Open, Ali review      | Complete current questionnaire based on shipped features; no medications or medical claims.                                                            |
| Name/subtitle/description         | Draft below           | Verify lengths, actual functionality and name availability in ASC.                                                                                     |
| Keywords/category/copyright       | Draft below           | Fitness category, Sideband copyright and accurate search terms.                                                                                        |
| Screenshots                       | Open                  | Synthetic data only, final UI, all required device sizes and localizations.                                                                            |
| Support URL                       | Partial               | https://sideband.studio resolves and lists hello@sideband.studio; prepare Exerly-specific help/deletion guidance.                                      |
| Review notes/test account         | Open                  | Synthetic account; explain HealthKit, permissions, offline use and account deletion. No credentials committed.                                         |
| Crash diagnostics                 | Open                  | MetricKit/TestFlight only, no third-party SDK. Document collection accurately.                                                                         |
| Two consecutive full audits       | Open                  | Zero completed clean audits.                                                                                                                           |
| External review / App Review      | Not authorized        | Prepare all material, then ask Ali.                                                                                                                    |

## Draft metadata

- Preferred name: Exerly.
- Fallback name: Exerly Training & Nutrition.
- Subtitle: Training, food and evidence.
- Primary locale: English US.
- SKU: sideband-exerly-ios.
- Primary category: Health & Fitness.
- Copyright: © Sideband.
- Support/contact: hello@sideband.studio, https://sideband.studio.
- Candidate keywords: workout,training,nutrition,macros,food,weight,strength,sets,reps,progress.

Draft description for the finished product, not the current build:

> Log training and food in one place. Record sets, meals and body measurements,
> review your progress, and keep logging when you are offline. Exerly shows the
> records behind its calculations. Agent suggestions arrive as changes you can
> review, accept or undo. Export your data or connect your own agent through scoped
> access. AI is optional.

Replace this draft with the capabilities actually verified at submission. Do not
claim full parity, superior food coverage or sub-second launch until measured.

## Internal test notes for the foundation build

Synthetic accounts only. This build adds a training logger backed by on-device
SQLite, workout history, previous-set prefill and persistent rest timers. Training
sync is not connected yet. The diary, onboarding, preferences and progress flows
remain available. Check training logging, one-tap completion, finish/history,
offline relaunch and account separation. Proposal review, complete nutrients and
migration flows are still under development.
Report crashes through TestFlight. Do not import personal health data yet.

[apps]: https://developer.apple.com/documentation/appstoreconnectapi/apps

[invite]: https://developer.apple.com/documentation/appstoreconnectapi/betatester/attributes-data.dictionary
