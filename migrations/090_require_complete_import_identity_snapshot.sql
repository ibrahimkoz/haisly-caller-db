SET LOCAL lock_timeout = '5s';
-- CHECK treats UNKNOWN as passing: require all three values explicitly for an existing identity.
ALTER TABLE contact_import_job_rows ADD CONSTRAINT contact_import_job_rows_complete_snapshot CHECK (
 (expected_contact_public_id IS NULL AND expected_version IS NULL AND expected_identity_revision IS NULL)
 OR (expected_contact_public_id IS NOT NULL AND expected_version IS NOT NULL
     AND expected_identity_revision IS NOT NULL AND expected_version > 0 AND expected_identity_revision > 0)
);
