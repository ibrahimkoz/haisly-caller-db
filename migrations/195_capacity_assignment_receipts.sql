SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_capacity_assignment_receipts (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 policy_id bigint NOT NULL REFERENCES public.caller_capacity_policies(id) ON DELETE RESTRICT,
 actor_platform_admin_user_id bigint NOT NULL REFERENCES public.platform_admin_users(id) ON DELETE RESTRICT,
 idempotency_key text NOT NULL CHECK(length(idempotency_key) BETWEEN 8 AND 200),
 request_hash text NOT NULL CHECK(request_hash ~ '^[a-f0-9]{64}$'),
 response_body jsonb NOT NULL CHECK(jsonb_typeof(response_body)='object' AND octet_length(response_body::text)<=16384),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(actor_platform_admin_user_id,idempotency_key)
);
CREATE INDEX caller_capacity_assignment_policy_idx ON public.caller_capacity_assignment_receipts(policy_id,id DESC);
CREATE FUNCTION public.guard_capacity_assignment_receipt() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 RAISE EXCEPTION 'Capacity assignment receipts are immutable' USING ERRCODE='23514';
END $$;
CREATE TRIGGER caller_capacity_assignment_receipt_guard BEFORE UPDATE OR DELETE ON public.caller_capacity_assignment_receipts
 FOR EACH ROW EXECUTE FUNCTION public.guard_capacity_assignment_receipt();
CREATE TRIGGER caller_capacity_assignment_receipt_no_truncate BEFORE TRUNCATE ON public.caller_capacity_assignment_receipts
 FOR EACH STATEMENT EXECUTE FUNCTION public.guard_capacity_assignment_receipt();
