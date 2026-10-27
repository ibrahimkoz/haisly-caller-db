SET LOCAL lock_timeout = '5s';
ALTER TABLE public.billing_budget_limits ADD COLUMN limit_revision integer NOT NULL DEFAULT 1 CHECK(limit_revision>0);
ALTER TABLE public.billing_budget_limits ADD CONSTRAINT billing_budget_scope UNIQUE(id,tenant_id);
CREATE TABLE public.billing_budget_events (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 tenant_id bigint NOT NULL,
 budget_id bigint NOT NULL,
 limit_revision integer NOT NULL CHECK(limit_revision>0),
 period_key text NOT NULL CHECK(period_key='lifetime' OR period_key ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
 event_code text NOT NULL CHECK(event_code IN ('near_limit','limit_reached','reserve_denied')),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(budget_id,limit_revision,period_key,event_code),
 FOREIGN KEY(budget_id,tenant_id) REFERENCES public.billing_budget_limits(id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX billing_budget_events_tenant_idx ON public.billing_budget_events(tenant_id,created_at);
CREATE OR REPLACE FUNCTION public.guard_billing_budget_limit() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Budget policies cannot be deleted.' USING ERRCODE='23514'; END IF;
 IF (NEW.id,NEW.public_id,NEW.tenant_id,NEW.scope,NEW.campaign_id,NEW.period_timezone,NEW.created_by_user_id,NEW.created_at)
  IS DISTINCT FROM (OLD.id,OLD.public_id,OLD.tenant_id,OLD.scope,OLD.campaign_id,OLD.period_timezone,OLD.created_by_user_id,OLD.created_at)
  OR NEW.version<>OLD.version+1 OR NEW.limit_revision<>OLD.limit_revision+(CASE WHEN NEW.limit_amount<>OLD.limit_amount THEN 1 ELSE 0 END) THEN
  RAISE EXCEPTION 'Budget scope is immutable and updates require the next version.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END;
$$;
CREATE FUNCTION public.guard_billing_budget_event() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Budget notification history is immutable.' USING ERRCODE='23514'; END;
$$;
CREATE TRIGGER billing_budget_event_guard BEFORE UPDATE OR DELETE ON public.billing_budget_events FOR EACH ROW EXECUTE FUNCTION public.guard_billing_budget_event();
