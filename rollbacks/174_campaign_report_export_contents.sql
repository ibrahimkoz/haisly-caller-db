SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_report_export_contents) THEN RAISE EXCEPTION 'Cannot drop stored report exports'; END IF;
END $$;
DROP TABLE public.caller_report_export_contents;
DROP FUNCTION public.guard_report_export_content();
ALTER TABLE public.export_jobs DROP CONSTRAINT export_jobs_id_tenant_unique;
