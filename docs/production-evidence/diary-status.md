# Diary logging status verification

September 22, 2026. Xcode 16.4, iPhone 16 Pro simulator on iOS 18.6, and headless Chrome. Tests use synthetic accounts and isolated databases.

People can explicitly mark a day in progress, complete, estimated or excluded and add a note. A partial diary remains in progress until changed. Only complete intake days with sufficient calorie and measurement evidence can inform the observed expenditure estimate. This implementation does not change the nutrition bounds or enable public automated advice.

Native status writes commit the account-scoped local record and pending operation together. They survive restart and remain visible while offline. A competing server revision requires review. Pending dependent edits use the acknowledged revision from the preceding operation; retries preserve both the operation key and sorted JSON request body.

The web form saves a draft under the account, API environment and day. Reload restores it. Save sends an immutable operation, and a conflict shows both the current server status and the draft. The user can keep the server result or submit the reviewed draft against its current revision. Browser drafts require an explicit Save; this is not a general background web synchronization queue.

Completed checks:

| Check                                            | Result                            | Local evidence                                          |
| ------------------------------------------------ | --------------------------------- | ------------------------------------------------------- |
| SQLite API suite                                 | 120 passed                        | `/tmp/exerly-production-sqlite-v11.log`                 |
| MongoDB replica-set suite                        | 120 passed                        | `/tmp/exerly-production-mongo-v10.log`                  |
| Native unit suite                                | 31 passed                         | `/tmp/exerly-production-diary-e2e-v2.xcresult`          |
| Native diary status journey                      | 1 passed                          | Same result bundle                                      |
| Browser diary and measurement journeys           | 2 passed                          | `/tmp/exerly-production-web-diary-e2e-v2.log`           |
| TypeScript and web production build              | Passed, bundle warning remains    | `/tmp/exerly-production-web-diary-v3.log`               |
| API/web format, ESLint, API smoke, workflow lint | Passed; 36 ESLint warnings remain | `format-v5`, `lint-v12`, `smoke-v5`, `workflow-v3` logs |
| Native lint                                      | Passed with warnings              | `/tmp/exerly-production-swiftlint-v4.log`               |

The native UI journey signs in, opens yesterday, chooses Complete, enters a note, makes the API unavailable and saves. It terminates and relaunches, checks the same note, restores connectivity and relaunches again. The server then has revision 1 for yesterday while today remains in progress. Unit tests independently cover lost acknowledgements followed by another offline edit, account isolation and competing status review.

The browser journey saves Complete, restores an unfinished draft after reload, encounters a concurrent Excluded status, reviews it and saves Estimated. A later Complete save deliberately loses its successful response. Reload and retry return the original acknowledgement without adding another revision. Summary and export match.

Reviewed captures:

- [Native offline status](diary-simulator/diary-status-offline.png)
- [Native synchronized status](diary-simulator/diary-status-synchronized.png)
- [Browser desktop](diary-web/diary-status-desktop.png)
- [Browser mobile](diary-web/diary-status-mobile.png)

The first native run failed on JSON key order and a field locator; the successful v2 run supersedes it. The first new web build required replacing an unsupported TypeScript library helper; the successful v3 build includes that fix. No production account or service was changed.
