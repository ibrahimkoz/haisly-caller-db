SET LOCAL lock_timeout='5s';
ALTER TABLE public.caller_campaign_versions
 ADD COLUMN callback_team_id bigint,
 ADD COLUMN callback_due_business_days integer NOT NULL DEFAULT 1 CHECK(callback_due_business_days BETWEEN 1 AND 30),
 ADD CONSTRAINT caller_callback_team_fk FOREIGN KEY(callback_team_id,tenant_id) REFERENCES public.caller_teams(id,tenant_id) ON DELETE RESTRICT;
CREATE INDEX caller_campaign_callback_team ON public.caller_campaign_versions(tenant_id,callback_team_id) WHERE callback_team_id IS NOT NULL;
CREATE FUNCTION public.guard_callback_follow_up_settings() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='UPDATE' AND NEW.callback_team_id IS NOT DISTINCT FROM OLD.callback_team_id AND NEW.callback_due_business_days=OLD.callback_due_business_days THEN RETURN NEW; END IF;
 IF TG_OP='INSERT' AND NEW.callback_team_id IS NULL AND NEW.callback_due_business_days=1 THEN RETURN NEW; END IF;
 IF NEW.state<>'draft' THEN RAISE EXCEPTION 'Callback follow-up settings require a draft' USING ERRCODE='23514'; END IF;
 IF NEW.callback_team_id IS NOT NULL THEN
  PERFORM id FROM public.caller_teams WHERE id=NEW.callback_team_id AND tenant_id=NEW.tenant_id AND archived_at IS NULL FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Callback team must be active in this tenant' USING ERRCODE='23514'; END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_callback_settings_guard BEFORE INSERT OR UPDATE ON public.caller_campaign_versions FOR EACH ROW EXECUTE FUNCTION public.guard_callback_follow_up_settings();
