# M11: webhooks for the person's own agents

Owner: logic agent. Status: built, 2026-10-06. PARITY B11, and the Beyond
seed "a developer platform: MCP server, OpenAPI, tokens and webhooks".

An agent, or a dashboard such as Ali's Ascension, should hear about new data
without polling `/v1/changes`.

## A notice, not the data

A webhook POST says only that the account's change feed moved on:
`{"type":"changes","webhook_id":…,"sequence":42,"sent_at":…}`. The receiver
reads `/v1/changes?after=` with its own token. So:

- a webhook can't leak data, even if its URL later changes hands;
- the token's scopes still decide what the receiver can read;
- several changes coalesce into one POST with the latest sequence.

## Authenticity

Each webhook has a secret, `whsec_…`, returned once at creation and never
exported. `Exerly-Signature: t=<unix seconds>,v1=<hex>` is HMAC-SHA256 of
`<t>.<raw body>`. Receivers should reject old timestamps. The secret is
stored as it is, because signing needs it, unlike token hashes.

## Safety

- **HTTPS only,** without credentials in the URL.
- **Public addresses only.** The host must resolve to a public address when
  the webhook is created, and every connection checks again through its own
  DNS lookup, so a rebound name can't reach the server's network. Literal
  private, loopback, link-local, shared (100.64/10), ULA and multicast
  addresses are refused. `EXERLY_WEBHOOKS_ALLOW_PRIVATE=1` lifts this, for
  tests and for a staging server whose receivers are on its own tailnet.
  Never set it on a public server.
- **No redirects,** a 5-second timeout, and at most 5 webhooks an account.
- **Tokens.** A webhook made with a personal access token belongs to it: the
  token sees only its own webhooks, and they stop when it is revoked or
  expires.

## Delivery

Every 10 seconds the server claims due webhooks in one `UPDATE`: enabled,
past their retry time, and behind their account's feed. A claim holds for 2
minutes, so two servers never send the same one at once. A 2xx records the
sequence. Anything else retries after 30 s, doubling up to 6 h, and 15
failures in a row disable the webhook until `POST /v1/webhooks/{id}/enable`.
