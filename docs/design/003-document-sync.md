# M1c: document sync for ExerlyCore

Owner: logic agent. Status: in progress, 2026-10-06.

## Problem

ExerlyCore keeps training data on the device. It has to reach the server for
backup, other devices, the MCP server and the person's own agents. That has to work
offline, survive lost responses, and never drop a set logged on one device while
another edits the same session.

## Model

ExerlyCore entities sync as **documents**. Each one is identified by:

- an account;
- a kind: `workout_session` or `custom_exercise` today, with more as features
  land;
- a client-generated ID.

The server stores the latest JSON payload, a server-assigned revision starting
at 1, and a tombstone when deleted. Every change appends to the existing
per-account change feed (`sync_changes`) in the same transaction.

**Endpoints** (versioned under `/v1`):

- `PUT /v1/documents/{kind}/{id}` with `{ payload, base_revision }`. Use base 0 to
  create.
  - It returns `409` with the current document when the base revision is stale.
  - `Idempotency-Key` makes retries safe: a replay returns the first response and
    bumps nothing.
- `DELETE /v1/documents/{kind}/{id}?base_revision=n` writes a tombstone (with a
  new revision), so a deletion reaches devices that were offline. A `PUT` on a
  tombstone with its revision restores it.
- `GET /v1/documents/{kind}/{id}` returns the document.
- `GET /v1/changes?after=cursor&limit=n` returns document changes in order. The
  returned cursor moves past legacy kinds in the shared feed, so v1 clients never
  stall on them.

**Wire format.**

- ExerlyCore's Codable JSON.
- Dates are ISO 8601 UTC strings with milliseconds.
- ExerlyCore rounds every date it creates to whole milliseconds, so a round trip
  through the server is exact.
- The server checks the kind, the ID format, and that the payload is an object
  whose `id` matches. It doesn't reinterpret payloads.

## Client

The sync engine keeps, per document:

- the last revision and payload it saw from the server (the base);
- whether the local copy has unpushed changes;
- the idempotency key of the pending push, kept until it is acknowledged, so a
  retry after a lost response replays instead of conflicting.

**Push.** Each dirty document is sent with its base revision.

- On `200`, the base becomes the pushed payload.
- On `409`, the engine merges, saves the result locally and pushes again, up to a
  bound.

**Pull.** Changes after the stored cursor are applied.

- A clean document takes the remote version.
- A dirty one is merged and stays dirty.

**Three-way merge** of base, local and remote:

- A scalar field takes whichever side changed it; when both did, local wins.
- Exercises and sets merge by ID, recursively. A side that added an item keeps it.
- A deletion on one side applies only if the other side left the item unchanged,
  so a set logged on one device survives an exercise deleted on another.
- The local order wins, and remote additions are appended.

## Acceptance

- Server:
  - revisions and stale-base conflicts;
  - idempotent replay;
  - tombstones and restore;
  - feed order and paging past legacy kinds;
  - per-account isolation, deletion and export coverage;
  - payload validation.
- Client:
  - the merge keeps concurrent additions and edits from both sides;
  - a lost acknowledgement replays without a conflict;
  - offline edits push in order when the network returns;
  - an end-to-end run against the real API on a throwaway database.
