SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_quality_alerts (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
 campaign_id bigint NOT NULL,
 opened_revision_id bigint NOT NULL,
 opened_score numeric(8,4) NOT NULL CHECK(opened_score>=0 AND opened_score<70),
 opened_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 notified_at timestamptz,
 recovered_revision_id bigint,
 recovered_score numeric(8,4) CHECK(recovered_score>=70 AND recovered_score<=100),
 recovered_at timestamptz,
 UNIQUE(id,tenant_id),
 FOREIGN KEY(campaign_id,tenant_id) REFERENCES public.caller_campaigns(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(opened_revision_id,tenant_id) REFERENCES public.caller_quality_assessment_revisions(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(recovered_revision_id,tenant_id) REFERENCES public.caller_quality_assessment_revisions(id,tenant_id) ON DELETE RESTRICT,
 CHECK((recovered_at IS NULL AND recovered_revision_id IS NULL AND recovered_score IS NULL)
    OR (recovered_at IS NOT NULL AND recovered_revision_id IS NOT NULL AND recovered_score IS NOT NULL)),
 CHECK(notified_at IS NULL OR notified_at>=opened_at),
 CHECK(recovered_at IS NULL OR recovered_at>=opened_at)
);
CREATE UNIQUE INDEX caller_quality_one_open_alert ON public.caller_quality_alerts(tenant_id,campaign_id) WHERE recovered_at IS NULL;
CREATE INDEX caller_quality_alert_history ON public.caller_quality_alerts(tenant_id,campaign_id,id DESC);
CREATE FUNCTION public.guard_quality_alert() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE revision_id bigint;
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Quality alert history cannot be deleted' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 IF TG_OP='UPDATE' THEN
  IF (NEW.id,NEW.public_id,NEW.tenant_id,NEW.campaign_id,NEW.opened_revision_id,NEW.opened_score,NEW.opened_at)
   IS DISTINCT FROM (OLD.id,OLD.public_id,OLD.tenant_id,OLD.campaign_id,OLD.opened_revision_id,OLD.opened_score,OLD.opened_at)
   OR (OLD.notified_at IS NOT NULL AND NEW.notified_at IS DISTINCT FROM OLD.notified_at)
   OR (OLD.recovered_at IS NOT NULL AND (NEW.recovered_at,NEW.recovered_revision_id,NEW.recovered_score)
    IS DISTINCT FROM (OLD.recovered_at,OLD.recovered_revision_id,OLD.recovered_score)) THEN
   RAISE EXCEPTION 'Quality alert provenance cannot be rewritten' USING ERRCODE='23514';
  END IF;
 ELSE
  IF NEW.recovered_at IS NOT NULL OR NEW.recovered_revision_id IS NOT NULL OR NEW.recovered_score IS NOT NULL OR NEW.notified_at IS NOT NULL THEN
   RAISE EXCEPTION 'Quality alert must start open and pending notification' USING ERRCODE='23514';
  END IF;
  NEW.opened_at:=clock_timestamp();
 END IF;
 FOREACH revision_id IN ARRAY ARRAY[NEW.opened_revision_id,NEW.recovered_revision_id] LOOP
  IF revision_id IS NOT NULL AND NOT EXISTS (
   SELECT 1 FROM public.caller_quality_assessment_revisions q JOIN public.caller_campaign_snapshots s
    ON s.id=q.snapshot_id AND s.tenant_id=q.tenant_id
   WHERE q.id=revision_id AND q.tenant_id=NEW.tenant_id AND s.campaign_id=NEW.campaign_id
  ) THEN RAISE EXCEPTION 'Quality alert revision does not belong to campaign' USING ERRCODE='23514'; END IF;
 END LOOP;
 IF TG_OP='UPDATE' THEN
  IF OLD.notified_at IS NULL AND NEW.notified_at IS NOT NULL THEN NEW.notified_at:=clock_timestamp(); END IF;
  IF OLD.recovered_at IS NULL AND NEW.recovered_at IS NOT NULL THEN NEW.recovered_at:=clock_timestamp(); END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_quality_alert_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_quality_alerts
 FOR EACH ROW EXECUTE FUNCTION public.guard_quality_alert();
