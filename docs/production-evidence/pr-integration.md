# Pull request integration checks

September 22, 2026. The implementation was combined with `origin/main` at `7b58e26e` in a separate worktree, keeping the MacBook preview running throughout. The branch preserves the merged dependency upgrades, GitHub Actions versions and removal of unused web components. Its new API storage adapters replace the unused PostgreSQL dependency, retain SQLite 6, and add the isolated MongoDB test runner.

`npm ci` succeeds with the combined lockfile. The latest checks use this dependency set:

| Check                               | Result                                                         | Evidence                                                                     |
| ----------------------------------- | -------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| API on SQLite                       | 153 passed                                                     | [SQLite](pr-integration/api-sqlite.log)                                      |
| API on MongoDB                      | 153 passed                                                     | [MongoDB](pr-integration/api-mongodb.log)                                    |
| API daily-loop smoke test           | Passed                                                         | [Smoke](pr-integration/smoke.log)                                            |
| Complete standalone Chromium suite  | 67 passed; one native-dependent activity/sleep journey skipped | [Browser](pr-integration/browser.log)                                        |
| Chromium production offline suite   | 13 passed                                                      | [Chromium](pr-integration/offline-chromium.log)                              |
| WebKit production offline suite     | 3 passed                                                       | [WebKit](pr-integration/offline-webkit.log)                                  |
| Update lifecycle regression         | 3 consecutive passes                                           | [Repeated update check](pr-integration/update-check.log)                     |
| TypeScript and production web build | Passed; existing large-chunk warning                           | [Typecheck](pr-integration/typecheck.log), [build](pr-integration/build.log) |
| ESLint                              | No errors; 18 warnings                                         | [Lint](pr-integration/lint.log)                                              |
| Repository formatting               | Passed                                                         | [Formatting](pr-integration/full-format.log)                                 |
| Workflow lint                       | Passed                                                         | [Actionlint](pr-integration/actionlint.log)                                  |
| Secret scan of new commits          | Passed                                                         | [Gitleaks](pr-integration/gitleaks.log)                                      |

Repository formatting preserves generated Hyperframes compositions and exported verification JSON. Handwritten source, scripts and documentation remain included.

The first Chromium production run passed 12 checks but stalled when evaluating the waiting service worker after closing its final app tab. The test now observes Chromium's worker lifecycle events through a separate debugging session on an uncontrolled `about:blank` tab. It waits for the exact waiting version to activate, then checks the reopened app's actual HTML and pending operation. It keeps the original assertions that an open older tab prevents activation and that the pending addition synchronizes exactly once. Production worker behavior did not change. The [initial failure](pr-integration/update-initial-failure.log) and final repeated checks are retained.

Gitleaks initially classified two unsigned native fixture tokens as generic API keys. The allowlist now matches only their exact synthetic account-a/account-b token shapes. Test files and real credentials remain subject to the normal rules.

`npm audit` reports 10 existing advisories, compared with 17 on the current main branch. No advisory IDs or affected packages were added. Existing results include two critical, three high, two moderate and three low findings. The remaining dependency work is separate from this integration; no forced major upgrade was made here.

The native source is unchanged by this integration. The preceding [food checks](food-recovery.md) passed 68 unit tests on iPhone SE and the portion/correction UI journey on iPhone SE and iPhone 16 Pro, all on iOS 18.6. The [earlier combined round trip](../MOBILE_PRODUCTION_STATUS.md) passed the shared activity/sleep journey skipped by this standalone browser run. The unsigned Release build passed on Xcode 16.4; remote Xcode 26 CI and signed release gates remain unverified at PR creation.

This is a draft PR for completed implementation work and its evidence. The [production ledger](../MOBILE_PRODUCTION_STATUS.md) still tracks unfinished recipes, saved meals, training, navigation, account lifecycle and release work. Opening the PR does not complete the production plan or deploy the app.

## Initial remote CI

The first remote runs passed API checks, workflow lint, SwiftLint, the secret scan and dependency review. The native release gate exposed the local fallback in `scripts/ios.sh` overriding the runner's selected Xcode 26.2 with `/Applications/Xcode.app`, which was Xcode 16.4. The script now respects a selected full Xcode and uses that fallback only for a Command Line Tools selection. A focused reproduction confirms the old failure and verifies selected-Xcode, explicit-override and fallback behavior. The SDK gate still rejects the local Xcode 16.4. The corrected native job must pass its remote rerun.

The [initial CodeQL gate](https://github.com/whoisaldo/Exerly-Fitness/runs/107034318726) reports ten findings: one critical, eight high and one medium. They cover dynamic MongoDB filter property writes, request/log formatting, the provider request helper, browser weight-draft storage and a test-fixture control. These findings require triage and resolution before the draft is ready for approval; they are not established as false positives by the local functional tests.
