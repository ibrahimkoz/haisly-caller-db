DROP INDEX public.caller_quality_notice_due;
ALTER TABLE public.caller_quality_alerts DROP COLUMN notification_available_at, DROP COLUMN notification_last_error;
