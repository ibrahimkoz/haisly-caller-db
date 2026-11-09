SET LOCAL lock_timeout = '5s';
-- Contacts already store their optional email in customers.primary_email.
ALTER TABLE public.contact_import_preview_rows
  ADD COLUMN email text CHECK (length(email) <= 254);
ALTER TABLE public.contact_import_job_rows
  DROP CONSTRAINT contact_import_job_rows_overwrite_fields_check,
  ADD CONSTRAINT contact_import_job_rows_overwrite_fields_check
    CHECK (overwrite_fields <@ ARRAY['first_name','last_name','title','email']::text[]);
