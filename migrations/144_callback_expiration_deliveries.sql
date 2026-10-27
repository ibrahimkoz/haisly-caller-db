SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_callback_expiration_deliveries (
 tenant_id bigint NOT NULL,
 callback_id bigint NOT NULL,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','succeeded','needs_review','dead_letter')),
 attempt_count integer NOT NULL DEFAULT 0 CHECK(attempt_count BETWEEN 0 AND 5),
 available_at timestamptz NOT NULL DEFAULT now(),
 completed_at timestamptz,
 last_error_code text CHECK(last_error_code IS NULL OR last_error_code IN ('processing_failed','dispatch_reconciliation_required')),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,callback_id),
 FOREIGN KEY(callback_id,tenant_id) REFERENCES public.caller_callback_plans(id,tenant_id) ON DELETE RESTRICT,
 CHECK((status='succeeded')=(completed_at IS NOT NULL)),
 CHECK(status<>'dead_letter' OR attempt_count=5),
 CHECK(status<>'needs_review' OR (last_error_code IS NOT NULL AND last_error_code='dispatch_reconciliation_required'))
);
CREATE INDEX caller_callback_expiration_retry_idx ON public.caller_callback_expiration_deliveries(tenant_id,available_at,callback_id) WHERE status='pending';
