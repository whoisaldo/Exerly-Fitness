-- External sign-in identities (Sign in with Apple), and the nonces of identity
-- tokens already used, so a captured token cannot be replayed.

CREATE TABLE account_identities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  account_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  provider text NOT NULL,
  subject text NOT NULL,
  email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  last_used_at timestamptz
);
CREATE UNIQUE INDEX account_identities_subject ON account_identities (provider, subject);
CREATE INDEX account_identities_account ON account_identities (account_id);

CREATE TABLE auth_nonces (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  nonce_hash text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX auth_nonces_hash ON auth_nonces (nonce_hash);
CREATE INDEX auth_nonces_created ON auth_nonces (created_at);
