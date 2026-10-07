# M10: importing Hevy and Strong history

Owner: logic agent. Status: built, 2026-10-06. PARITY I13, and the Beyond
seed "Migration in: … Hevy and Strong exports". T20's backfill uses the same
`TrainingStore.importSessions`.

## Formats, as exported

Checked against public samples of real exports (2026-10-06):

- **Hevy** (Profile → Settings → Export data): comma-separated, quoted. The
  columns are `title`, `start_time`, `end_time`, `description`,
  `exercise_title`, `superset_id`, `exercise_notes`, `set_index`, `set_type`
  (`normal`, `warmup`, `failure`, `dropset`), `weight_kg` or `weight_lbs`,
  `reps`, `distance_km` or `distance_miles`, `duration_seconds` and `rpe`.
  Times are local without a zone, like "22 Dec 2025, 08:00". The rows sharing
  a title, start and end are one workout.
- **Strong**: newer files are semicolon-separated, with `Workout #`, `Date`
  ("2025-04-29 12:00:00"), `Workout Name`, `Duration (sec)`, `Exercise
Name`, `Set Order`, `Weight (kg)` or `Weight (lbs)`, `Reps`, `RPE`,
  `Distance (meters)`, `Seconds`, `Notes` and `Workout Notes`. Older files
  are comma-separated, with `Duration` like "1h 5m" and `Weight` and
  `Distance` without a unit. `Set Order` is a number, or a letter for warm-up,
  drop or failure sets. Rest-timer rows are not sets.

## Reading

- Times are read in the person's time zone, which the app passes in.
- A unit the file doesn't state is taken from the person's preference, and
  the result says so.
- RPE becomes RIR as 10 − RPE.
- Sets are spread evenly from the start to the end of the workout, since the
  files don't time them.
- A set missing what its exercise records, such as a weighted exercise with
  no weight, is left out, and the result says why.

## Matching exercises

Both apps name exercises like "Bench Press (Barbell)". A name matches, in
order:

1. the person's own mapping;
2. a short table of common names whose words differ from the library's;
3. a library exercise whose name or alias has exactly the same words;
4. the same without the parenthesised equipment, if the exercise uses that
   equipment.

Nothing else is guessed. Unmatched names are left out and listed with their
set counts. The app asks the person to map them, then parses again.

## Idempotent

Session, exercise, superset and set IDs are name-based UUIDs from the
workout's key and positions. Parsing the same file again gives identical
sessions, and `importSessions` adds only IDs it doesn't have. So: map first,
then import, because an imported workout isn't changed by a later import.
