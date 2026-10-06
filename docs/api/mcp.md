# Exerly MCP server

Connect your own agent (Claude, ChatGPT, or any client that speaks the Model
Context Protocol) to your Exerly training log. It reads your data through the
same calculations as the app and suggests changes as proposals that you review
in Exerly. It never changes your data directly.

## Connecting

- **URL:** `https://<your Exerly API>/mcp`. Streamable HTTP, stateless; use `POST`.
- **Authentication:** a personal access token, sent as `Authorization: Bearer exr_…`.
  Create one in Exerly or with `POST /v1/tokens` (see `openapi.yaml`). Signed-in
  app sessions are refused here.
- **Scopes:**
  - `read`: every read tool.
  - `propose`: read, plus `propose`.
  - `write`: the same tools as `propose` here. Direct writes exist only on the REST API.
- **Limits:** 120 requests a minute.

## Tools

| Tool                    | What it returns                                                                                                                                    |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `get_profile`           | Time zone, today's date there, preferred units, how much is logged, pending proposals.                                                             |
| `list_workouts`         | Workouts newest first, with local date, duration, exercises, working sets and volume.                                                              |
| `get_workout`           | One workout set by set: loads as entered and in kilograms, reps, RIR, set kinds, e1RM per set, volume per muscle, and the personal records it set. |
| `exercise_history`      | Statistics (e1RM, 3RM and 10RM estimates, heaviest load, volume, reps, sets), e1RM per workout and recent sets. Takes an ID or a name.             |
| `weekly_volume`         | Fractional sets and volume per muscle for recent weeks.                                                                                            |
| `search_exercises`      | Library and custom exercises, best match first.                                                                                                    |
| `list_proposals`        | Proposals and their status.                                                                                                                        |
| `list_programs`         | Programs: the active one, cycles, deload placement, days and progress.                                                                             |
| `next_workout`          | The next workout of the active program, with Exerly's recommended load, reps and RIR per set and the reason.                                       |
| `get_nutrition_day`     | One day's food log: entries, totals for every nutrient, the targets that held that day, what remains and the day's status.                         |
| `get_nutrition_summary` | Daily intake against targets, scale weight, and trend weight and expenditure with their standard deviations, for up to a year.                     |
| `get_document`          | A workout or custom exercise exactly as Exerly stores it, to edit into a proposal.                                                                 |
| `verify_metric`         | Recomputes a number before you cite it.                                                                                                            |
| `propose`               | Files a proposal (needs `propose` or `write`).                                                                                                     |

Loads are kilograms and volume is kilogram-reps unless a field says otherwise.
The numbers come from a JavaScript port of ExerlyCore that is tested against
a golden file generated from Swift (`docs/api/golden/training-v1.json`), so an
agent quotes exactly what the app shows.

## Proposals

A proposal names each document it changes, by kind (`workout_session`,
`custom_exercise` or `program`) and ID, and gives the full document it proposes as `after`, or
`null` to delete. The server fills in `before` from the stored document and
refuses an `after` the phone couldn't apply. You add:

- a title and a summary;
- evidence, each with a level: `humanRCT`, `observational`, `mechanism`,
  `anecdote` or `personalData` (your own data, n=1), plus caveats;
- an optional metric on a piece of evidence (for example `exercise.e1rm.best`
  with `exercise`, `from` and `through`). Exerly recomputes it and labels the
  evidence verified or mismatched, and `propose` reports the result back;
- a confidence (`low`, `medium` or `high`) and a falsifier: what would show the
  proposal is wrong.

The proposal appears in Exerly with its diff and evidence. Nothing changes until
you accept it. Accepting applies every change at once, and only if the data is
still what the proposal was computed against; otherwise it is marked stale. You
can undo an accepted proposal, and the audit log records who filed it, with
which token, and what you decided.

## Example

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "exercise_history",
    "arguments": { "exercise": "bench press", "from": "2026-09-01" }
  }
}
```
