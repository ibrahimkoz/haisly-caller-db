SET LOCAL lock_timeout='5s';
ALTER TABLE public.caller_quality_alerts
 ADD COLUMN notification_available_at timestamptz NOT NULL DEFAULT clock_timestamp() CHECK(isfinite(notification_available_at)),
 ADD COLUMN notification_last_error text CHECK(notification_last_error IN ('owner_unavailable','evidence_incomplete','processing_failed'));
CREATE INDEX caller_quality_notice_due ON public.caller_quality_alerts(tenant_id,notification_available_at,id)
 WHERE recovered_at IS NULL AND notified_at IS NULL;
