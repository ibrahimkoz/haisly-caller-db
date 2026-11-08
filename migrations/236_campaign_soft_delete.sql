SET LOCAL lock_timeout='5s';
-- Separate tombstone preserves immutable canceled campaigns and all their history.
CREATE TABLE public.caller_campaign_deletions (
 campaign_id bigint NOT NULL,
 tenant_id bigint NOT NULL,
 deleted_by_user_id bigint NOT NULL,
 deleted_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(campaign_id,tenant_id),
 FOREIGN KEY(campaign_id,tenant_id) REFERENCES public.caller_campaigns(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(deleted_by_user_id,tenant_id) REFERENCES public.users(id,tenant_id) ON DELETE RESTRICT
);
CREATE FUNCTION public.guard_campaign_deletion() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE campaign public.caller_campaigns%ROWTYPE;
BEGIN
 IF TG_OP <> 'INSERT' THEN RAISE EXCEPTION 'Campaign deletion history is immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 SELECT * INTO campaign FROM public.caller_campaigns WHERE id=NEW.campaign_id AND tenant_id=NEW.tenant_id FOR UPDATE;
 IF NOT FOUND OR campaign.state NOT IN ('draft','canceled') THEN RAISE EXCEPTION 'Cancel ongoing campaign work before deleting' USING ERRCODE='23514'; END IF;
 IF campaign.state='draft' AND EXISTS(SELECT 1 FROM public.caller_campaign_targets WHERE campaign_id=NEW.campaign_id AND tenant_id=NEW.tenant_id) THEN
  RAISE EXCEPTION 'Cancel campaign targets before deleting' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_campaign_deletion_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_campaign_deletions FOR EACH ROW EXECUTE FUNCTION public.guard_campaign_deletion();
