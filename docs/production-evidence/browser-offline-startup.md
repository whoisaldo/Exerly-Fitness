# Browser offline startup

Implemented September 22, 2026. All accounts and server interruptions in this record use isolated local fixtures.

The original browser lost its account bootstrap when the API became unavailable during a reload. The diary and its locally pending water addition then became inaccessible. The initial failing reproduction is `/tmp/exerly-browser-offline-red-v1.log`.

## Behavior

- Successful bootstrap and selected display reads now save to IndexedDB. Copies belong to the configured API, sign-in identity and account. Signing out removes that sign-in's copies. A different account cannot use them, and an old request cannot populate a new account's cache.
- Network failures, request timeouts and server outages can return a saved display response. A confirmed session revocation ends access. Invalid successful bootstrap responses remain errors and preserve the earlier valid copy.
- The connection banner shows when the screen uses a copy and when it was saved. A day without a saved response stays unknown. Date-specific queries retain their day, and undated copies are limited to the account day on which the request began.
- Cached bootstrap can open the app while session renewal is unavailable. Every server operation still passes through authenticated networking. Conflict review, reconciliation reads and mutation acknowledgements use server responses. A cached total cannot confirm a queued addition.
- Reads refresh when the browser reconnects, returns to the foreground or the user selects Refresh saved data. Pending additions retain their original operation and remain marked pending until the server confirms them. This batch does not add automatic replay to every browser queue.
- Accepted profile and setup responses update the saved bootstrap before their callers report completion. An immediate offline reload retains the accepted time zone and completed setup.
- Storage failures do not prevent online use. Unreadable copies are preserved, with no database reset. The display cache has a budget of 64 responses and approximately 2 MiB per sign-in, with a 1 MiB response limit. Eviction does not touch drafts or pending operations.

The covered display reads are bootstrap, diary summary, Home statistics/recent entries, weight day/trend, measurement history, program/check-ins and recent personal foods. Other screens keep their existing persistence behavior. Browser food quick-add/removal and structured workout recovery still require the remaining production-plan work.

## Production app shell

Each Vite build creates `offline-worker.js` from the exact HTML, scripts, styles, fonts and icons it produced. The worker saves the whole shell before installation succeeds. All lazy route scripts are included, so an unvisited route can open while disconnected. API/auth responses, the phone demo videos, uploads and private data never enter this cache.

The Inter font is served locally, removing the external font stylesheet from startup. The verified shell contains 16 files totaling 1,508,301 bytes. The video still loads only after the user presses Play.

An update waits until every tab using the previous build closes. It does not force a reload or take over an open form. The app announces a waiting update, including while showing an offline copy. Old shell versions are removed during activation. Account copies and pending writes remain separate from shell updates.

Registration is limited to production builds in a secure context. Use HTTPS for a deployed preview; localhost is suitable for automated tests. The ordinary HTTP development preview at port 3305 intentionally does not install a worker. See [MDN's service-worker lifecycle and secure-context guidance](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API/Using_Service_Workers).

## Verification

The reproducible commands are:

```sh
npm run test:web
npm run test:web:offline
PLAYWRIGHT_BROWSER=webkit npm run test:web -- apps/web/e2e/offline-startup.spec.ts --output=artifacts/web-offline-webkit-read-tests
PLAYWRIGHT_BROWSER=webkit npm run test:web:offline
```

`playwright.offline.config.cjs` builds into `artifacts/web-offline-dist` and serves that production output on port 3306 with an isolated API on port 39006. The ordinary browser suite uses separate fixtures on 3301/39002.

The shell journey warms a 500 ml diary, disconnects the web/API fixture sockets, adds 250 ml, closes the tab, reopens the app offline and visits a previously unvisited lazy route. Reconnection and an explicit retry produce exactly 750 ml on the server. Chromium also runs with browser network emulation disabled during the outage. The update journey installs a second shell while an addition is pending, confirms the old shell survives a reload, closes both old tabs and verifies the new shell retains that operation.

Playwright 1.63's service-worker interception is Chromium-only. The first WebKit attempt used page routing and network emulation; its failures are recorded in `/tmp/exerly-browser-offline-webkit-v1.log`. The production WebKit journeys now interrupt the actual local server sockets. They keep the service worker enabled. Cached-data fault injection runs separately against the development app. This follows [Playwright's documented service-worker automation limits](https://playwright.dev/docs/service-workers).

The wider regression also caught a delayed mutation acknowledgement being discarded after sign-out. Reads are now cancelled when their sign-in changes; an already-sent mutation response can still clear its original account's queue. Existing callers guard account-specific UI updates. The account-switch regression verifies the second account stays empty and the original account returns with its acknowledged entry.

| Check                              | Result                                          | Evidence                                                  |
| ---------------------------------- | ----------------------------------------------- | --------------------------------------------------------- |
| Chrome browser regression          | 53 passed, one native-dependent journey skipped | [Regression run](browser-offline/browser-regression.log)  |
| Standard production build          | Passed, existing bundle-size warning            | [Build](browser-offline/production-build.log)             |
| Chrome production build            | 12 passed                                       | [Production run](browser-offline/chromium-production.log) |
| WebKit production build            | 2 passed                                        | [Production run](browser-offline/webkit-production.log)   |
| WebKit cached-data fault injection | 10 passed                                       | [Cached-data run](browser-offline/webkit-reads.log)       |
| TypeScript                         | Passed                                          | [Typecheck](browser-offline/typecheck.log)                |
| ESLint                             | No errors, 25 existing warnings                 | [Lint](browser-offline/eslint.log)                        |
| Web/config formatting              | Passed                                          | [Formatting](browser-offline/format.log)                  |

The production captures show the original 500 ml and the separate 250 ml awaiting confirmation after a tab has closed and reopened: [Chrome](browser-offline/chromium-diary-reopened.png), [WebKit](browser-offline/webkit-diary-reopened.png). The [shell manifest](browser-offline/shell-assets.json) records the cached public files.

The update test initially checked the registration's active worker too early, which could still be the old worker. It now observes activation in the new worker before opening the next tab, then verifies that tab's actual HTML and pending operation. The initial timing failures are retained in `/tmp/exerly-browser-offline-production-v2.log` and `/tmp/exerly-browser-offline-production-final.log`; the complete passing Chrome run is `/tmp/exerly-browser-offline-production-v5.log`.

CI contains the browser and production-shell commands; remote CI has not run. The skipped activity/sleep return journey requires the shared native fixture. It passed in the preceding calendar batch’s combined cross-client v12 run; it is not counted as a pass in this standalone browser run.

## Remaining release evidence

These checks exercise Chrome and Playwright WebKit on the development Mac. They do not establish physical-iPhone Safari behavior, installed home-screen lifecycle, storage eviction under OS pressure or every shipped browser-storage migration. Those remain release checks alongside the production plan's account lifecycle, remaining durable writes, navigation, training, HealthKit and operational work.
