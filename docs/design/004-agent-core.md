# M2: the agent core

Owner: logic agent. Status: in progress, 2026-10-06.

## Problem

The brief's first principle is that agents propose and people decide. Anything an
agent changes has to be:

- a reviewable proposal, with a diff, evidence, a confidence level and what would
  prove it wrong;
- accepted with one tap;
- written to an audit log;
- undoable.

The same rules apply to the in-app agent and to the person's own agents, which
connect through MCP and the API with scoped tokens. Numbers come from code, never
from a model's prose.

## Model (ExerlyCore)

A **proposal** is a synced document (kind `proposal`). It holds:

- **author**: built-in, MCP or API, plus a display name and token ID;
- **title** and a short **summary** (model prose);
- **changes**: each names a document (kind and ID), the canonical payload it was
  computed against (`before`; nil to create) and the payload it proposes
  (`after`; nil to delete);
- **evidence**: a claim, an evidence level (human RCT, observational, mechanism,
  anecdote, or this person's own data), caveats such as "n=1" or "short window",
  links to the logged data it rests on, and optionally a **metric reference**
  (described below);
- **confidence** (low, medium or high) and a **falsifier**: what would show the
  proposal wrong;
- **status**: pending, accepted, rejected, undone or stale, with when it was
  decided.

**Accepting** applies every change as one unit, and only if each target still
equals its `before`. If anything changed since the proposal was made, it is
marked stale and nothing is applied.

**Undo** restores every `before`, as long as each target still equals its
`after`.

**Diffs** come from the before and after payloads, as field paths with old and new
values. Screens render them; ExerlyCore computes them.

**Metric references** keep agents honest. Evidence can name a metric ExerlyCore
knows, with its parameters and the value claimed, for example the best e1RM of
back squat from 2026-09-01 to 2026-10-01 in kilograms. ExerlyCore recomputes it
and labels the evidence verified, mismatched or unverifiable. A number an agent
invented never appears as fact.

**Audit events** are create-only synced documents (kind `audit_event`). They
record:

- proposals being created, accepted, rejected, undone or found stale;
- direct writes by write-scoped tokens;
- token creation and revocation.

## Server

**Kinds.**

- `proposal`: a personal access token may create only pending proposals. Status
  changes need a signed-in session; that is the person deciding.
- `audit_event`: create-only. An update or delete is refused.

**Personal access tokens.**

- Format: `exr_` plus 32 random bytes. Only a SHA-256 hash is stored, and the
  token is shown once.
- Scopes: `read`; `propose` (read plus creating proposals); and `write` (read
  plus document writes).
- A token never manages tokens, sessions, identities, passwords or account
  deletion, and only reaches `/v1/*` and `/mcp`.
- Each token records when it was last used. Write-scoped writes add audit
  events.
- Tokens are managed under `/v1/tokens`, by a signed-in session only.

**MCP** is a Streamable HTTP endpoint at `/mcp`, built on the official TypeScript
SDK and authenticated with a token.

- Read tools: workouts in a range, one workout, exercise history and
  statistics, weekly volume per muscle, records, exercise search, and proposals.
- Write tool: `propose`. It creates a pending proposal; it never changes data
  directly.

**Calculations** on the server are a JavaScript port of ExerlyCore's training
maths. A golden file generated from Swift (`docs/api/golden/training-v1.json`)
is asserted by both test suites, so the two implementations can't drift.

Built (M2c): the tools are `get_profile`, `list_workouts`, `get_workout`,
`exercise_history`, `weekly_volume`, `search_exercises`, `list_proposals`,
`get_document`, `verify_metric` and, for `propose` and `write` tokens, `propose`.
`propose` fills each change's `before` from the stored document, refuses an
`after` ExerlyCore couldn't apply, and reports how each cited metric verifies.
The guide for agent authors is `docs/api/mcp.md`.

## First agent features

These run on training data with code-computed evidence:

- **Entry errors.** Likely mistakes such as a load ten times the exercise's
  history, pounds entered as kilograms, or a rep count with a stray digit. Each
  becomes a correction proposal with before and after.
- **Stall diagnosis.** For each exercise: the e1RM slope over the recent
  sessions, the sessions in that window, the RIR trend and the weekly sets for
  its target muscles. The evidence carries its caveats.
- **Deload signal.** Several lifts lose e1RM at the same RIR, or the same loads
  feel harder. It is reported with its evidence. Deload proposals need programs
  (M4), so for now this is a diagnosis.

## Acceptance

- Accepting applies all changes or none, and refuses stale targets.
- Undo restores exactly, and refuses once the data has moved on.
- Proposals and audit events sync, and audit events can't be edited.
- A propose-only token can't write data or decide a proposal, and no token can
  manage tokens or the account.
- A mismatched metric reference is labelled mismatched.
- The JavaScript and Swift calculations agree on the golden file.
- The detectors are checked against simulated training with known errors,
  stalls and fatigue, and their error rates are recorded.
