-- Personal access tokens for the person's own agents (MCP and the API).
-- Only a SHA-256 hash of each token is stored.

CREATE TABLE personal_access_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  account_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  name text NOT NULL,
  token_hash text NOT NULL,
  prefix text NOT NULL,
  scopes jsonb NOT NULL,
  created_at timestamptz NOT NULL,
  last_used_at timestamptz,
  expires_at timestamptz,
  revoked_at timestamptz
);
CREATE UNIQUE INDEX personal_access_tokens_hash ON personal_access_tokens (token_hash);
CREATE INDEX personal_access_tokens_account ON personal_access_tokens (account_id);
