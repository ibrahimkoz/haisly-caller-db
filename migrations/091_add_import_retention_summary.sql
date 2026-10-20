SET LOCAL lock_timeout = '5s';
ALTER TABLE contact_import_previews ADD COLUMN data_purged_at timestamptz;
ALTER TABLE contact_import_jobs
 ADD COLUMN retained_pending integer CHECK (retained_pending BETWEEN 0 AND 50000),
 ADD COLUMN retained_applied integer CHECK (retained_applied BETWEEN 0 AND 50000),
 ADD COLUMN retained_conflict integer CHECK (retained_conflict BETWEEN 0 AND 50000),
 ADD COLUMN retained_skipped integer CHECK (retained_skipped BETWEEN 0 AND 50000),
 ADD CONSTRAINT contact_import_jobs_retained_counts_complete CHECK (
  (retained_pending IS NULL AND retained_applied IS NULL AND retained_conflict IS NULL AND retained_skipped IS NULL)
  OR (retained_pending IS NOT NULL AND retained_applied IS NOT NULL AND retained_conflict IS NOT NULL AND retained_skipped IS NOT NULL AND state IN ('completed','cancelled'))
 );
CREATE INDEX contact_import_previews_retention_idx ON contact_import_previews(tenant_id, expires_at, id) WHERE data_purged_at IS NULL;
