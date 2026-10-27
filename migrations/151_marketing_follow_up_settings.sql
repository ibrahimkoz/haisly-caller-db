SET LOCAL lock_timeout='5s';
ALTER TABLE public.caller_campaign_versions
 ADD COLUMN marketing_team_id bigint,
 ADD COLUMN marketing_due_business_days integer NOT NULL DEFAULT 1 CHECK(marketing_due_business_days BETWEEN 1 AND 30),
 ADD COLUMN marketing_follow_up_mode text NOT NULL DEFAULT 'automatic' CHECK(marketing_follow_up_mode IN ('automatic','review')),
 ADD CONSTRAINT caller_marketing_team_fk FOREIGN KEY(marketing_team_id,tenant_id) REFERENCES public.caller_teams(id,tenant_id) ON DELETE RESTRICT;
CREATE INDEX caller_campaign_marketing_team ON public.caller_campaign_versions(tenant_id,marketing_team_id) WHERE marketing_team_id IS NOT NULL;
CREATE FUNCTION public.guard_marketing_follow_up_settings() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='UPDATE' AND NEW.marketing_team_id IS NOT DISTINCT FROM OLD.marketing_team_id AND NEW.marketing_due_business_days=OLD.marketing_due_business_days AND NEW.marketing_follow_up_mode=OLD.marketing_follow_up_mode THEN RETURN NEW; END IF;
 IF TG_OP='INSERT' AND NEW.marketing_team_id IS NULL AND NEW.marketing_due_business_days=1 AND NEW.marketing_follow_up_mode='automatic' THEN RETURN NEW; END IF;
 IF NEW.state<>'draft' THEN RAISE EXCEPTION 'Marketing follow-up settings require a draft' USING ERRCODE='23514'; END IF;
 IF NEW.marketing_team_id IS NOT NULL THEN
  PERFORM id FROM public.caller_teams WHERE id=NEW.marketing_team_id AND tenant_id=NEW.tenant_id AND archived_at IS NULL FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Marketing team must be active in this tenant' USING ERRCODE='23514'; END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_marketing_settings_guard BEFORE INSERT OR UPDATE ON public.caller_campaign_versions FOR EACH ROW EXECUTE FUNCTION public.guard_marketing_follow_up_settings();
