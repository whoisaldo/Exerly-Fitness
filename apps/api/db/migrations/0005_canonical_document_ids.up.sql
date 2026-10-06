-- Document IDs that are UUIDs are stored in uppercase, the form ExerlyCore
-- writes, so one document can never have two rows. If an account already has
-- both forms of one ID, the unique index stops this migration rather than
-- guess which copy to keep; staging had no such rows on 2026-10-06.

UPDATE documents
   SET document_id = upper(document_id)
 WHERE document_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
   AND document_id <> upper(document_id);

-- The change feed reads these rows. Legacy kinds keep their lowercase IDs.
UPDATE sync_changes
   SET entity_id = upper(entity_id)
 WHERE kind IN ('workout_session', 'custom_exercise', 'proposal', 'audit_event')
   AND entity_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
   AND entity_id <> upper(entity_id);
