# Foundation and barcode verification

Date: September 21, 2026. Machine: devbox1, macOS 15.7.9, Apple M1 Max.

| Check                             | Result                                      | Limit                                                                            |
| --------------------------------- | ------------------------------------------- | -------------------------------------------------------------------------------- |
| API baseline                      | 81 passed                                   | Existing suite, SQLite                                                           |
| Audit regressions before fixes    | 2 failed                                    | Expected program mismatch and stale-measurement confidence failures              |
| API after foundation/barcode work | 101 passed on SQLite; 101 passed on MongoDB | Isolated in-memory SQLite and MongoDB 7.0.24 replica set, no production database |
| Swift unit tests                  | 10 passed                                   | Xcode 16.4, iOS 18.6 simulator                                                   |
| UI test                           | 1 passed                                    | Welcome to sign-in navigation only                                               |
| Native build                      | Passed                                      | Simulator; no physical-device validation                                         |
| API lint                          | Passed                                      | ESLint                                                                           |
| Web typecheck                     | Passed                                      | Browser flow verification remains                                                |
| GitHub main protection            | Absent                                      | Read-only inspection returned HTTP 404, Branch not protected                     |

Synthetic GTIN fixtures cover check digits and identity aliases. Provider response fixtures cover missing products, server failure, rate limits, malformed responses, unknown nutrients, volume basis and sodium units. They do not establish provider coverage or camera reliability.

The public-release gate remains open. See the implementation ledger for remaining work.
