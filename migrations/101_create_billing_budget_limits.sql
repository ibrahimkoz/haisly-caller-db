SET LOCAL lock_timeout = '5s';
CREATE TABLE public.billing_budget_limits (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
 scope text NOT NULL CHECK(scope IN ('monthly','campaign','inbound')),
 campaign_id bigint,
 limit_amount numeric(20,6) NOT NULL CHECK(limit_amount>=0),
 period_timezone text NOT NULL DEFAULT 'UTC' CHECK(period_timezone='UTC'),
 state text NOT NULL DEFAULT 'ready' CHECK(state IN ('ready','paused')),
 pause_reason text CHECK(pause_reason IN ('user','limit')),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 created_by_user_id bigint NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(campaign_id,tenant_id) REFERENCES public.caller_campaigns(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(created_by_user_id,tenant_id) REFERENCES public.users(id,tenant_id) ON DELETE RESTRICT,
 CHECK((scope='campaign' AND campaign_id IS NOT NULL) OR (scope<>'campaign' AND campaign_id IS NULL)),
 CHECK((state='ready' AND pause_reason IS NULL) OR (state='paused' AND pause_reason IS NOT NULL))
);
CREATE UNIQUE INDEX billing_budget_campaign_unique ON public.billing_budget_limits(tenant_id,campaign_id) WHERE scope='campaign';
CREATE UNIQUE INDEX billing_budget_general_unique ON public.billing_budget_limits(tenant_id,scope) WHERE scope<>'campaign';
CREATE INDEX billing_budget_page_idx ON public.billing_budget_limits(tenant_id,scope,public_id);
CREATE INDEX billing_reservation_month_idx ON public.billing_reservations(tenant_id,created_at) INCLUDE(state,reserved_amount,sale_amount,purpose);
CREATE INDEX billing_reservation_campaign_idx ON public.billing_reservations(tenant_id,campaign_id) INCLUDE(state,reserved_amount,sale_amount);
CREATE FUNCTION public.guard_billing_budget_limit() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Budget policies cannot be deleted.' USING ERRCODE='23514'; END IF;
 IF (NEW.id,NEW.public_id,NEW.tenant_id,NEW.scope,NEW.campaign_id,NEW.period_timezone,NEW.created_by_user_id,NEW.created_at)
  IS DISTINCT FROM (OLD.id,OLD.public_id,OLD.tenant_id,OLD.scope,OLD.campaign_id,OLD.period_timezone,OLD.created_by_user_id,OLD.created_at)
  OR NEW.version<>OLD.version+1 THEN
  RAISE EXCEPTION 'Budget scope is immutable and updates require the next version.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER billing_budget_limit_guard BEFORE UPDATE OR DELETE ON public.billing_budget_limits FOR EACH ROW EXECUTE FUNCTION public.guard_billing_budget_limit();
