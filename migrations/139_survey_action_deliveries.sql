SET LOCAL lock_timeout = '5s';
CREATE TABLE public.caller_survey_action_deliveries (
 tenant_id bigint NOT NULL,
 outbox_event_id bigint NOT NULL,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','succeeded','dead_letter')),
 attempt_count integer NOT NULL DEFAULT 0 CHECK(attempt_count BETWEEN 0 AND 5),
 available_at timestamptz NOT NULL DEFAULT now(),
 completed_at timestamptz,
 last_error_code text CHECK(last_error_code IS NULL OR last_error_code='processing_failed'),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,outbox_event_id),
 FOREIGN KEY(outbox_event_id,tenant_id) REFERENCES public.outbox_events(id,tenant_id) ON DELETE RESTRICT,
 CHECK((status='succeeded')=(completed_at IS NOT NULL)),
 CHECK(status<>'dead_letter' OR attempt_count=5)
);
CREATE INDEX caller_survey_delivery_retry_idx ON public.caller_survey_action_deliveries(tenant_id,available_at,outbox_event_id) WHERE status='pending';
-- The shared outbox status is deliberately untouched: other consumers own their receipts.
