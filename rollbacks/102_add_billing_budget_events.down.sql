SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.billing_budget_events LIMIT 1) THEN RAISE EXCEPTION 'Budget events exist; use a forward fix.'; END IF;
END $$;
DROP TABLE public.billing_budget_events;
DROP FUNCTION public.guard_billing_budget_event();
CREATE OR REPLACE FUNCTION public.guard_billing_budget_limit() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Budget policies cannot be deleted.' USING ERRCODE='23514'; END IF;
 IF (NEW.id,NEW.public_id,NEW.tenant_id,NEW.scope,NEW.campaign_id,NEW.period_timezone,NEW.created_by_user_id,NEW.created_at)
  IS DISTINCT FROM (OLD.id,OLD.public_id,OLD.tenant_id,OLD.scope,OLD.campaign_id,OLD.period_timezone,OLD.created_by_user_id,OLD.created_at)
  OR NEW.version<>OLD.version+1 THEN RAISE EXCEPTION 'Budget scope is immutable and updates require the next version.' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END;
$$;
ALTER TABLE public.billing_budget_limits DROP CONSTRAINT billing_budget_scope;
ALTER TABLE public.billing_budget_limits DROP COLUMN limit_revision;
