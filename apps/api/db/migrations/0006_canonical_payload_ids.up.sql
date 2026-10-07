-- The IDs inside stored payloads, in the canonical form 0005 gave the ID
-- columns: a payload's own ID and the document IDs it refers to. Mirrors
-- canonicalPayload in lib/documents.js; the tests check they agree.

CREATE OR REPLACE FUNCTION pg_temp.canonical_id(value jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN jsonb_typeof(value) = 'string'
     AND value #>> '{}' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    THEN to_jsonb(upper(value #>> '{}'))
    ELSE value
  END
$$;

-- `value` with `key` set to `mapped`, when it is an object that has the key.
CREATE OR REPLACE FUNCTION pg_temp.map_key(value jsonb, key text, mapped jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN jsonb_typeof(value) = 'object' AND value ? key
    THEN jsonb_set(value, ARRAY[key], mapped)
    ELSE value
  END
$$;

CREATE OR REPLACE FUNCTION pg_temp.with_id(value jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE AS $$
  SELECT pg_temp.map_key(value, 'id', pg_temp.canonical_id(value -> 'id'))
$$;

CREATE OR REPLACE FUNCTION pg_temp.refs(list jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN jsonb_typeof(list) = 'array'
    THEN (SELECT coalesce(jsonb_agg(pg_temp.with_id(ref) ORDER BY n), '[]')
            FROM jsonb_array_elements(list) WITH ORDINALITY AS t (ref, n))
    ELSE list
  END
$$;

CREATE OR REPLACE FUNCTION pg_temp.changes(list jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN jsonb_typeof(list) = 'array'
    THEN (SELECT coalesce(jsonb_agg(
                   pg_temp.map_key(pg_temp.map_key(pg_temp.with_id(change),
                     'before', pg_temp.with_id(change -> 'before')),
                     'after', pg_temp.with_id(change -> 'after'))
                   ORDER BY n), '[]')
            FROM jsonb_array_elements(list) WITH ORDINALITY AS t (change, n))
    ELSE list
  END
$$;

CREATE OR REPLACE FUNCTION pg_temp.evidence(list jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN jsonb_typeof(list) = 'array'
    THEN (SELECT coalesce(jsonb_agg(
                   pg_temp.map_key(item, 'dataRefs', pg_temp.refs(item -> 'dataRefs'))
                   ORDER BY n), '[]')
            FROM jsonb_array_elements(list) WITH ORDINALITY AS t (item, n))
    ELSE list
  END
$$;

CREATE OR REPLACE FUNCTION pg_temp.canonical_payload(kind text, payload jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE kind
    WHEN 'proposal' THEN
      pg_temp.map_key(pg_temp.map_key(document, 'changes', pg_temp.changes(document -> 'changes')),
                      'evidence', pg_temp.evidence(document -> 'evidence'))
    WHEN 'audit_event' THEN
      pg_temp.map_key(pg_temp.map_key(document, 'targets', pg_temp.refs(document -> 'targets')),
                      'proposalID', pg_temp.canonical_id(document -> 'proposalID'))
    ELSE document
  END
  FROM (SELECT pg_temp.with_id(payload) AS document) AS t
$$;

UPDATE documents
   SET payload = pg_temp.canonical_payload(kind, payload)
 WHERE payload IS NOT NULL
   AND payload <> pg_temp.canonical_payload(kind, payload);

-- The change feed returns these payloads to devices that sync from the start.
UPDATE sync_changes
   SET payload = jsonb_set(payload, '{payload}', pg_temp.canonical_payload(kind, payload -> 'payload'))
 WHERE kind IN ('workout_session', 'custom_exercise', 'proposal', 'audit_event')
   AND jsonb_typeof(payload -> 'payload') = 'object'
   AND payload -> 'payload' <> pg_temp.canonical_payload(kind, payload -> 'payload');
