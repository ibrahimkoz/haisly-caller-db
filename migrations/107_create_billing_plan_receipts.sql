SET LOCAL lock_timeout = '5s';
CREATE TABLE public.billing_plan_creation_receipts (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 actor_platform_admin_user_id bigint NOT NULL REFERENCES public.platform_admin_users(id) ON DELETE RESTRICT,
 pricing_plan_id bigint NOT NULL UNIQUE REFERENCES public.pricing_plans(id) ON DELETE RESTRICT,
 idempotency_key text NOT NULL CHECK(length(idempotency_key) BETWEEN 8 AND 200),
 request_hash text NOT NULL CHECK(request_hash ~ '^[0-9a-f]{64}$'),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(actor_platform_admin_user_id,idempotency_key)
);
CREATE FUNCTION public.guard_billing_plan_receipt() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Plan creation receipts are immutable.' USING ERRCODE='23514'; END;
$$;
CREATE TRIGGER billing_plan_receipt_guard BEFORE UPDATE OR DELETE ON public.billing_plan_creation_receipts FOR EACH ROW EXECUTE FUNCTION public.guard_billing_plan_receipt();
