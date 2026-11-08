-- Retire standalone privacy administration. Runtime consent evidence remains in use.
SET LOCAL lock_timeout='5s';
DROP TABLE public.retention_policies, public.data_export_requests,
 public.data_deletion_requests, public.pii_redaction_jobs;
