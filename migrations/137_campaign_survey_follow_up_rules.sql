SET LOCAL lock_timeout = '5s';
CREATE TABLE public.caller_campaign_survey_follow_up_rules (
 tenant_id bigint NOT NULL,
 campaign_version_id bigint NOT NULL,
 question_key text NOT NULL CHECK(question_key ~ '^[A-Za-z][A-Za-z0-9_-]{0,63}$'),
 team_id bigint NOT NULL,
 threshold integer CHECK(threshold BETWEEN 0 AND 10),
 mode text NOT NULL CHECK(mode IN ('automatic','review')),
 due_business_days integer NOT NULL CHECK(due_business_days BETWEEN 1 AND 30),
 PRIMARY KEY(tenant_id,campaign_version_id,question_key),
 FOREIGN KEY(campaign_version_id,tenant_id) REFERENCES public.caller_campaign_versions(id,tenant_id) ON DELETE CASCADE,
 FOREIGN KEY(team_id,tenant_id) REFERENCES public.caller_teams(id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_survey_follow_up_team_idx ON public.caller_campaign_survey_follow_up_rules(tenant_id,team_id);
-- Rules are edited only on drafts; immutable snapshots store the public rule contract.
CREATE FUNCTION public.caller_guard_survey_follow_up_rule() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='UPDATE' AND (NEW.tenant_id,NEW.campaign_version_id,NEW.question_key) IS DISTINCT FROM
  (OLD.tenant_id,OLD.campaign_version_id,OLD.question_key) THEN
  RAISE EXCEPTION 'Rule identity is immutable' USING ERRCODE='23514';
 END IF;
 PERFORM v.id FROM public.caller_campaign_versions v JOIN public.caller_campaigns c ON c.id=v.campaign_id AND c.tenant_id=v.tenant_id
 WHERE v.id=NEW.campaign_version_id AND v.tenant_id=NEW.tenant_id AND v.state='draft' AND c.campaign_type='survey' FOR SHARE OF v,c;
 IF NOT FOUND THEN RAISE EXCEPTION 'Survey follow-up rule requires a survey draft' USING ERRCODE='23514'; END IF;
 PERFORM id FROM public.caller_teams WHERE id=NEW.team_id AND tenant_id=NEW.tenant_id AND archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Follow-up team must be active' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER caller_survey_follow_up_rule_guard BEFORE INSERT OR UPDATE ON public.caller_campaign_survey_follow_up_rules
 FOR EACH ROW EXECUTE FUNCTION public.caller_guard_survey_follow_up_rule();
