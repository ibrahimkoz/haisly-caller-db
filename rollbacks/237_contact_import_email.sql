SET LOCAL lock_timeout = '5s';
-- Refuse rollback while email overwrite approvals exist; do not silently discard them.
ALTER TABLE public.contact_import_job_rows
  DROP CONSTRAINT contact_import_job_rows_overwrite_fields_check,
  ADD CONSTRAINT contact_import_job_rows_overwrite_fields_check
    CHECK (overwrite_fields <@ ARRAY['first_name','last_name','title']::text[]);
ALTER TABLE public.contact_import_preview_rows DROP COLUMN email;
