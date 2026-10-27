SET LOCAL lock_timeout = '5s';
ALTER TABLE public.caller_campaign_snapshots ADD CONSTRAINT caller_campaign_snapshot_scope UNIQUE(id,campaign_id,tenant_id);
CREATE TABLE public.caller_campaign_targets (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 campaign_id bigint NOT NULL,
 snapshot_id bigint NOT NULL,
 customer_id bigint NOT NULL,
 identity_revision integer NOT NULL CHECK(identity_revision>0),
 display_name_snapshot text NOT NULL,
 state text NOT NULL DEFAULT 'held' CHECK(state='held'),
 attempt_count integer NOT NULL DEFAULT 0 CHECK(attempt_count>=0),
 first_attempt_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK((attempt_count=0 AND first_attempt_at IS NULL) OR (attempt_count>0 AND first_attempt_at IS NOT NULL)),
 UNIQUE(id,tenant_id),
 UNIQUE(campaign_id,customer_id),
 FOREIGN KEY(campaign_id,tenant_id) REFERENCES public.caller_campaigns(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(snapshot_id,campaign_id,tenant_id) REFERENCES public.caller_campaign_snapshots(id,campaign_id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(customer_id,tenant_id) REFERENCES public.customers(id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_campaign_targets_page_idx ON public.caller_campaign_targets(tenant_id,campaign_id,public_id);
CREATE INDEX caller_campaign_targets_identity_idx ON public.caller_campaign_targets(tenant_id,customer_id,identity_revision);
CREATE TABLE public.caller_campaign_target_sources (
 tenant_id bigint NOT NULL,
 target_id bigint NOT NULL,
 list_id bigint NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(target_id,list_id),
 FOREIGN KEY(target_id,tenant_id) REFERENCES public.caller_campaign_targets(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(list_id,tenant_id) REFERENCES public.contact_lists(id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_campaign_target_sources_list_idx ON public.caller_campaign_target_sources(tenant_id,list_id);
CREATE FUNCTION public.guard_caller_campaign_target() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE person public.customers%ROWTYPE;
BEGIN
 IF TG_OP='DELETE' THEN
  RAISE EXCEPTION 'Campaign target history cannot be deleted.' USING ERRCODE='23514';
 END IF;
 IF TG_OP='INSERT' THEN
  SELECT * INTO person FROM public.customers WHERE id=NEW.customer_id AND tenant_id=NEW.tenant_id FOR SHARE;
  IF NOT FOUND OR person.identity_revision<>NEW.identity_revision THEN
   RAISE EXCEPTION 'Campaign target identity is stale or foreign.' USING ERRCODE='23514';
  END IF;
  NEW.display_name_snapshot:=person.display_name;
 ELSE
  IF (NEW.id,NEW.public_id,NEW.tenant_id,NEW.campaign_id,NEW.customer_id,NEW.identity_revision,NEW.display_name_snapshot,NEW.created_at)
    IS DISTINCT FROM (OLD.id,OLD.public_id,OLD.tenant_id,OLD.campaign_id,OLD.customer_id,OLD.identity_revision,OLD.display_name_snapshot,OLD.created_at) THEN
   RAISE EXCEPTION 'Campaign target identity and provenance are immutable.' USING ERRCODE='23514';
  END IF;
  IF NEW.attempt_count<OLD.attempt_count OR (OLD.first_attempt_at IS NOT NULL AND NEW.first_attempt_at IS DISTINCT FROM OLD.first_attempt_at) THEN
   RAISE EXCEPTION 'Campaign target attempt history cannot be reset.' USING ERRCODE='23514';
  END IF;
  IF NEW.snapshot_id<>OLD.snapshot_id AND (OLD.attempt_count>0 OR OLD.first_attempt_at IS NOT NULL OR NEW.attempt_count>0) THEN
   RAISE EXCEPTION 'Started targets cannot change campaign snapshot.' USING ERRCODE='23514';
  END IF;
 END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER caller_campaign_target_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_campaign_targets
 FOR EACH ROW EXECUTE FUNCTION public.guard_caller_campaign_target();
CREATE FUNCTION public.guard_caller_campaign_target_source() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='INSERT' THEN
  PERFORM m.customer_id FROM public.contact_list_members m
   JOIN public.caller_campaign_targets t ON t.customer_id=m.customer_id AND t.tenant_id=m.tenant_id
   WHERE t.id=NEW.target_id AND t.tenant_id=NEW.tenant_id AND m.list_id=NEW.list_id FOR SHARE OF m;
  IF NOT FOUND THEN
   RAISE EXCEPTION 'Target source requires a current matching membership.' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
 END IF;
 RAISE EXCEPTION 'Campaign target source provenance is immutable.' USING ERRCODE='23514';
END;
$$;
CREATE TRIGGER caller_campaign_target_source_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_campaign_target_sources
 FOR EACH ROW EXECUTE FUNCTION public.guard_caller_campaign_target_source();
