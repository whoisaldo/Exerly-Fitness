-- ExerlyCore entities synced as documents: the latest payload per account,
-- kind and client ID, with a server revision and a tombstone on deletion.

CREATE TABLE documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seq bigint GENERATED ALWAYS AS IDENTITY,
  account_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  kind text NOT NULL,
  document_id text NOT NULL,
  revision integer NOT NULL CHECK (revision > 0),
  payload jsonb,
  deleted_at timestamptz,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  CHECK ((payload IS NULL) = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX documents_identity ON documents (account_id, kind, document_id);
