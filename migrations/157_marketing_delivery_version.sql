SET LOCAL lock_timeout = '5s';
ALTER TABLE public.caller_marketing_action_deliveries ADD COLUMN version integer NOT NULL DEFAULT 1 CHECK(version > 0);
CREATE FUNCTION public.bump_marketing_delivery_version() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF OLD.version = 2147483647 THEN RAISE EXCEPTION 'Marketing delivery version exhausted'; END IF;
 NEW.version := OLD.version + 1;
 NEW.updated_at := clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER marketing_delivery_version BEFORE UPDATE ON public.caller_marketing_action_deliveries FOR EACH ROW EXECUTE FUNCTION public.bump_marketing_delivery_version();
CREATE INDEX caller_marketing_delivery_failures ON public.caller_marketing_action_deliveries(tenant_id,outbox_event_id) WHERE status='dead_letter';
