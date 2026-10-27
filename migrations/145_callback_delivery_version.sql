SET LOCAL lock_timeout = '5s';
ALTER TABLE public.caller_callback_expiration_deliveries ADD COLUMN version integer NOT NULL DEFAULT 1 CHECK(version > 0);
CREATE FUNCTION public.bump_callback_delivery_version() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF OLD.version = 2147483647 THEN RAISE EXCEPTION 'Callback delivery version exhausted'; END IF;
 NEW.version := OLD.version + 1;
 RETURN NEW;
END $$;
CREATE TRIGGER callback_delivery_version BEFORE UPDATE ON public.caller_callback_expiration_deliveries FOR EACH ROW EXECUTE FUNCTION public.bump_callback_delivery_version();
CREATE INDEX caller_callback_expiration_scan ON public.caller_callback_plans(tenant_id, window_ends_at, id) WHERE state = 'pending';
