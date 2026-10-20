SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM contact_import_previews WHERE data_purged_at IS NOT NULL) THEN
  RAISE EXCEPTION 'Retention already purged source rows; restore a backup instead of discarding retained counters.';
 END IF;
END $$;
DROP INDEX contact_import_previews_retention_idx;
ALTER TABLE contact_import_jobs DROP CONSTRAINT contact_import_jobs_retained_counts_complete,
 DROP COLUMN retained_pending, DROP COLUMN retained_applied, DROP COLUMN retained_conflict, DROP COLUMN retained_skipped;
ALTER TABLE contact_import_previews DROP COLUMN data_purged_at;
