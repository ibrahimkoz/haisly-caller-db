SET LOCAL lock_timeout = '5s';
ALTER TABLE public.leads ADD COLUMN version integer NOT NULL DEFAULT 1 CHECK(version > 0);
CREATE FUNCTION public.bump_caller_lead_version() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF OLD.version = 2147483647 THEN RAISE EXCEPTION 'Lead version exhausted'; END IF;
 NEW.version := OLD.version + 1;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_lead_version BEFORE UPDATE ON public.leads FOR EACH ROW EXECUTE FUNCTION public.bump_caller_lead_version();
CREATE INDEX caller_lead_owner_read ON public.leads(tenant_id,owner_user_id,created_at DESC,id);
