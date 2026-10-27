SET LOCAL lock_timeout='5s';
CREATE FUNCTION public.valid_caller_quality_weights(value jsonb) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE key text; total numeric:=0; amount numeric;
BEGIN
 IF value IS NULL OR jsonb_typeof(value)<>'object' THEN RETURN false; END IF;
 IF (SELECT count(*) FROM jsonb_object_keys(value))<>4 THEN RETURN false; END IF;
 FOREACH key IN ARRAY ARRAY['objective','grounding','identity_tone','preference_tools'] LOOP
  IF jsonb_typeof(value->key) IS DISTINCT FROM 'number' THEN RETURN false; END IF;
  amount:=(value->>key)::numeric;
  IF amount<0 OR amount>100 OR amount<>trunc(amount) THEN RETURN false; END IF;
  total:=total+amount;
 END LOOP;
 RETURN total=100;
END $$;
CREATE TABLE public.caller_quality_policies (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE RESTRICT,
 version integer NOT NULL CHECK(version>0),
 weights jsonb NOT NULL CHECK(public.valid_caller_quality_weights(weights)),
 created_by_user_id bigint NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,version),
 FOREIGN KEY(created_by_user_id,tenant_id) REFERENCES public.users(id,tenant_id) ON DELETE RESTRICT
);
CREATE FUNCTION public.guard_caller_quality_policy() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE previous integer;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Quality policies are immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 SELECT max(version) INTO previous FROM public.caller_quality_policies WHERE tenant_id=NEW.tenant_id;
 IF NEW.version<>coalesce(previous,0)+1 THEN RAISE EXCEPTION 'Quality policy version changed' USING ERRCODE='23514'; END IF;
 IF NOT EXISTS (
  SELECT 1 FROM public.users u JOIN public.tenant_memberships m ON m.user_id=u.id AND m.tenant_id=NEW.tenant_id
  JOIN public.user_roles ur ON ur.user_id=u.id AND ur.tenant_id=m.tenant_id
  JOIN public.roles r ON r.id=ur.role_id AND r.tenant_id=ur.tenant_id
  WHERE u.id=NEW.created_by_user_id AND u.status='active' AND u.deleted_at IS NULL
   AND m.status='active' AND m.deleted_at IS NULL AND ur.status='active' AND ur.revoked_at IS NULL
   AND r.status='active' AND r.code='owner'
 ) THEN RAISE EXCEPTION 'Quality policy requires active tenant owner' USING ERRCODE='23514'; END IF;
 NEW.created_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER caller_quality_policy_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_quality_policies
 FOR EACH ROW EXECUTE FUNCTION public.guard_caller_quality_policy();
ALTER TABLE public.caller_campaign_snapshots
 ADD COLUMN quality_policy_id bigint,
 ADD COLUMN quality_weights jsonb NOT NULL DEFAULT '{"objective":30,"grounding":25,"identity_tone":20,"preference_tools":25}'::jsonb CHECK(public.valid_caller_quality_weights(quality_weights)),
 ADD CONSTRAINT caller_snapshot_quality_policy_fk FOREIGN KEY(quality_policy_id,tenant_id) REFERENCES public.caller_quality_policies(id,tenant_id) ON DELETE RESTRICT;
CREATE INDEX caller_snapshot_quality_policy_idx ON public.caller_campaign_snapshots(tenant_id,quality_policy_id) WHERE quality_policy_id IS NOT NULL;
CREATE FUNCTION public.guard_snapshot_quality_weights() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE policy public.caller_quality_policies%ROWTYPE; expected jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 SELECT * INTO policy FROM public.caller_quality_policies WHERE tenant_id=NEW.tenant_id ORDER BY version DESC LIMIT 1;
 expected:=coalesce(policy.weights,'{"objective":30,"grounding":25,"identity_tone":20,"preference_tools":25}'::jsonb);
 IF NEW.quality_policy_id IS DISTINCT FROM policy.id OR NEW.quality_weights IS DISTINCT FROM expected THEN
  RAISE EXCEPTION 'Snapshot must capture current tenant quality policy' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_snapshot_quality_guard BEFORE INSERT ON public.caller_campaign_snapshots
 FOR EACH ROW EXECUTE FUNCTION public.guard_snapshot_quality_weights();
CREATE FUNCTION public.guard_model_quality_weights() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE expected jsonb;
BEGIN
 IF NEW.assessment_source<>'model_assessment' THEN RETURN NEW; END IF;
 SELECT s.quality_weights INTO expected FROM public.caller_call_end_snapshots e
 JOIN public.caller_campaign_snapshots s ON s.id=e.snapshot_id AND s.tenant_id=e.tenant_id
 WHERE e.runtime_binding_id=NEW.runtime_binding_id AND e.tenant_id=NEW.tenant_id;
 IF expected IS NULL OR NEW.assessment->'weights' IS DISTINCT FROM expected THEN
  RAISE EXCEPTION 'Model quality weights must match captured campaign policy' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_quality_weights_guard BEFORE INSERT ON public.caller_quality_assessment_revisions
 FOR EACH ROW EXECUTE FUNCTION public.guard_model_quality_weights();
