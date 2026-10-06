# A2: training shell and logger

2026-10-06. App owner. Builds on the ExerlyCore training and SQLite contracts.

The new Train tab opens a saved workout immediately. A new session starts with a
name and optional current bodyweight, then an exercise search. Each set shows its
previous performance, editable values, type and RIR, and a completion control.
The Core store supplies previous sets, validation, rest choices and history.
Completing a prefilled set takes one tap. Unfinished work survives a relaunch.

Use a native five-tab shell: Home, Train, Library, Progress and Profile. Keep the
existing diary and account flows reachable. Preserve Exerly's dark default and
purple/pink accents, with Light and System options in Profile and scalable system type.
At accessibility sizes set rows stack vertically; controls keep 44-point targets.
Errors stay visible and failed writes never appear saved. Motion is incidental.

The app composes one TrainingStore per authenticated account. Use SQLiteTrainingPersistence.defaultURL(accountID:) so account deletion and
workspace creation agree on the same account-specific path. Recreate the shell when the account changes. A storage
failure gets a retry screen, without a temporary in-memory replacement. Test
stores use a separate UUID directory in Debug only.

Tests come first: database isolation and restart recovery through app composition;
strict localized numeric input; a simulator flow that logs, relaunches, completes
and finds the workout in history. Inspect light/dark screenshots on the small and
large app simulators at the largest Dynamic Type size. Run the full native suite
and device build before landing, then upload an internal milestone build.

Rest persistence, calculated session summaries and completeness flags have been
requested from logic. Do not duplicate those calculations in the UI. The first
screen can show individual saved sets and timestamps while that contract lands.
Training sync is not implemented by this milestone; label its local storage
accurately. Programs, Watch and agent proposals follow their own contracts.
