# M14: CSV exports and importing an export

Owner: logic agent. Status: built, 2026-10-07. PARITY I14 ("all entities, IDs,
revisions, UTC/timezone, provenance and nutrient unknowns; import round-trip"),
and the Beyond seed "full-fidelity JSON/CSV/xlsx export".

## JSON

`/api/export` already returns every table the account owns, including every
document with its ID, revision and timestamps, and leaves out credentials and
webhook secrets. It is the format that can be imported.

## CSV, one file per kind

`GET /v1/export/<file>.csv`, with a session or any token:

| File                | One row per                                    |
| ------------------- | ---------------------------------------------- |
| `food_entries.csv`  | logged food, with its nutrients for the amount |
| `saved_foods.csv`   | saved food, with nutrients per 100 g           |
| `weigh_ins.csv`     | weigh-in                                       |
| `days.csv`          | day status, notes and tags                     |
| `sets.csv`          | effort of a set (a drop set has several)       |
| `metric_values.csv` | custom metric value                            |
| `metrics.csv`       | custom metric                                  |

- Every row has the document ID, revision and `updated_at` in UTC. Instants
  are UTC; dates are the person's local dates, and sessions carry their time
  zone.
- Provenance is kept: food source and ID, a volume basis and whether its
  density was assumed, a weigh-in's source, and program references.
- Nutrient columns name their unit (`energy_kcal`, `sodium_mg`,
  `vitaminD_mcg`), one per nutrient ExerlyCore knows. A nutrient the food
  doesn't report is an empty cell, never 0.
- Cells follow RFC 4180. Text starting with `=`, `+`, `-` or `@` gets a leading
  apostrophe, so a food named like a formula can't run in a spreadsheet.

xlsx isn't produced. CSV opens in every spreadsheet, and a workbook writer
would add a dependency for no gain in fidelity.

## Import

`POST /v1/import` takes the JSON export, from the person's own app only.

- Each document is checked as an API write would be, then added with its
  exported revision.
- A document the account already has is kept as it is, so importing twice
  changes nothing and nothing newer is overwritten.
- Legacy tables in the export are listed, not imported.
- One audit event records the import.
- The cap is 25 MB, against 256 kB for other requests.

## Checked

`api.portability.test.js` covers CSV columns, empty unknowns, escaping and
formulas, and a seven-kind round trip between two accounts, where every
document, ID, revision and payload matches and a second import changes
nothing. `LiveSyncTests` does the same through ExerlyCore's client against the
real API: an export made on one phone imports into a second account, and that
account's phone syncs entries, weigh-ins and sessions equal to the first.
