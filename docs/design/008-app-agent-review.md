# A4: review agent changes and connect your own agent

App owner, 2026-10-06. Use the published AgentStore and AccountAPI contracts.
Keep Exerly's purple/pink theme and dark default. A3 remains isolated in the
primary worktree until its final checks and release finish.

Training opens Suggestions, a native list of pending proposals and decisions.
A proposal shows its title, author, date, summary, confidence and what would show
it wrong. Review displays every changed field from AgentStore.diff, named in
workout terms with explicit before/after values and units. Whole-document creates
or removals show the full workout structure. Unknown fields remain inspectable;
never hide a change behind a friendly summary. Evidence has its level, caveats,
source and links to the original workout. A metric is recomputed by Core and
clearly labelled verified, mismatched or unavailable. Never repeat an agent's
claim as a measured fact.

Accept and Reject call AgentStore directly. Accept is one tap from the complete
review. An accepted proposal offers Undo. Stale, invalid or failed writes explain
why nothing changed. Decisions trigger the shared account's sync, and still work
offline. Account changes replace the entire workspace. Audit history lists every
Core event, newest first, including its actor, time, proposal and affected data.
Screens format Core values; they do not compute training metrics or mutate JSON.

Profile opens Connect an agent. List the account's access tokens with name,
permission, last use and expiry. New tokens default to Read and propose; Read
only is also available. Direct write is an explicit advanced choice requiring a
confirmation that it can change records without proposal review. Token creation
uses the account-bound API. Show the secret only on the resulting screen, with
a deliberate copy action and an expiring, device-local clipboard item. Never log
it, persist it, put it in screenshots, or make it a preview fixture. Closing the
screen clears the local secret. Revoke requires confirmation, refreshes the list,
and keeps failures visible. Present the MCP endpoint from the compiled API URL
and explain that connecting grants that agent access to the selected data.

Tests first: meaningful presentation checks cover workout field labels/units,
complete fallback values and all evidence verification states; actual Core
store tests exercise the screen's decision wrapper, stale failures and undo.
Hosted token tests use a controlled SessionTransport to check scope choices,
account-bound errors and list refresh after revoke. Simulator flows file synthetic
proposals through the real fixture API, sync, review, accept, inspect the changed
workout, undo, reject and reopen the audit. A second flow creates a synthetic
propose-only token and revokes it; capture only list/form/confirmation, never a
secret. Include failure and offline decisions, and all four largest-text
light/dark small/large variants. Upload an internal build after the full checks.

Entry-error detection and training signals follow this review foundation. Do not
expose a detector without the evidence and decision path working end to end.
