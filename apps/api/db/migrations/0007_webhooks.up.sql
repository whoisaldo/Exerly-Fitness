-- Webhooks: a signed notice to the person's own HTTPS endpoint that their
-- change feed moved on. A delivery carries a sequence number, never data; the
-- receiver reads /v1/changes with its own token. See lib/webhooks.js.

CREATE TABLE webhooks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  account_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  token_id uuid REFERENCES personal_access_tokens (id) ON DELETE CASCADE,
  url text NOT NULL,
  secret text NOT NULL,
  created_at timestamptz NOT NULL,
  delivered_sequence double precision NOT NULL DEFAULT 0,
  next_attempt_at timestamptz NOT NULL,
  failures integer NOT NULL DEFAULT 0,
  last_delivery_at timestamptz,
  last_error text,
  disabled_at timestamptz
);
CREATE INDEX webhooks_account ON webhooks (account_id);
CREATE INDEX webhooks_due ON webhooks (next_attempt_at) WHERE disabled_at IS NULL;
