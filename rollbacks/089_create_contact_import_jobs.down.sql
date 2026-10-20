DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM contact_import_jobs) THEN
  RAISE EXCEPTION 'Import jobs exist; rollback would lose approved work';
 END IF;
END $$;
DROP TABLE contact_import_job_rows;
DROP TABLE contact_import_jobs;
ALTER TABLE background_jobs DROP CONSTRAINT background_jobs_id_tenant_key;
