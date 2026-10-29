SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_test_dispatch_intents (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 test_number_id bigint NOT NULL,
 release_artifact_id bigint NOT NULL,
 provider_account_id bigint NOT NULL,
 reservation_id bigint NOT NULL UNIQUE,
 canonical_phone text NOT NULL CHECK(canonical_phone ~ '^\+[1-9][0-9]{7,14}$'),
 request_key uuid NOT NULL,
 request_hash text NOT NULL CHECK(request_hash ~ '^[a-f0-9]{64}$'),
 tenant_timezone text NOT NULL,
 quota_date date NOT NULL,
 state text NOT NULL DEFAULT 'prepared' CHECK(state IN ('prepared','submitting','uncertain','accepted','ended','rejected','canceled')),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 provider_call_ref text CHECK(length(btrim(provider_call_ref)) BETWEEN 1 AND 200),
 evidence_reference text CHECK(length(btrim(evidence_reference)) BETWEEN 1 AND 1000),
 accepted_at timestamptz,
 ended_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,request_key), UNIQUE(provider_account_id,provider_call_ref),
 FOREIGN KEY(test_number_id,tenant_id) REFERENCES public.caller_test_numbers(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(release_artifact_id,tenant_id) REFERENCES public.caller_release_artifacts(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(provider_account_id,tenant_id) REFERENCES public.telephony_provider_accounts(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(reservation_id,tenant_id) REFERENCES public.billing_reservations(id,tenant_id) ON DELETE RESTRICT,
 CHECK((state IN ('prepared','submitting','uncertain','rejected','canceled') AND accepted_at IS NULL AND ended_at IS NULL AND provider_call_ref IS NULL)
  OR (state='accepted' AND accepted_at IS NOT NULL AND ended_at IS NULL AND provider_call_ref IS NOT NULL)
  OR (state='ended' AND accepted_at IS NOT NULL AND ended_at IS NOT NULL AND provider_call_ref IS NOT NULL)),
 CHECK((accepted_at IS NULL OR (isfinite(accepted_at) AND accepted_at>=created_at)) AND (ended_at IS NULL OR (isfinite(ended_at) AND ended_at>=accepted_at))),
 CHECK(state='prepared' OR evidence_reference IS NOT NULL)
);
CREATE UNIQUE INDEX caller_test_dispatch_open_phone ON public.caller_test_dispatch_intents(tenant_id,canonical_phone)
 WHERE state IN ('prepared','submitting','uncertain','accepted');
CREATE INDEX caller_test_dispatch_quota_idx ON public.caller_test_dispatch_intents(tenant_id,quota_date,state);
CREATE INDEX caller_test_dispatch_acceptance_idx ON public.caller_test_dispatch_intents(tenant_id,accepted_at) WHERE accepted_at IS NOT NULL;
CREATE INDEX caller_test_dispatch_history_idx ON public.caller_test_dispatch_intents(tenant_id,canonical_phone,ended_at DESC) WHERE ended_at IS NOT NULL;
CREATE FUNCTION public.guard_test_dispatch_intent() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE selected record; now_at timestamptz;
BEGIN
 IF TG_OP IN ('DELETE','TRUNCATE') THEN RAISE EXCEPTION 'Test dispatch history is immutable' USING ERRCODE='23514'; END IF;
 IF current_setting('transaction_isolation')<>'read committed' THEN RAISE EXCEPTION 'Test dispatch requires READ COMMITTED' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id,0));
 now_at:=clock_timestamp();
 IF TG_OP='INSERT' THEN
  SELECT n.canonical_phone,t.timezone INTO selected FROM public.caller_test_numbers n
   JOIN public.tenants t ON t.id=n.tenant_id AND t.status='active' AND t.deleted_at IS NULL
   JOIN public.caller_release_artifacts a ON a.id=NEW.release_artifact_id AND a.tenant_id=n.tenant_id
   JOIN public.caller_campaign_snapshots snapshot ON snapshot.id=a.snapshot_id AND snapshot.tenant_id=a.tenant_id
   JOIN public.telephony_provider_accounts p ON p.id=NEW.provider_account_id AND p.tenant_id=n.tenant_id AND p.tenant_environment_id=a.tenant_environment_id AND p.status='active'
   JOIN public.billing_reservations r ON r.id=NEW.reservation_id AND r.tenant_id=n.tenant_id AND r.purpose='test' AND r.state='held' AND r.campaign_id=snapshot.campaign_id AND r.reference_key=NEW.request_key::text
   WHERE n.id=NEW.test_number_id AND n.tenant_id=NEW.tenant_id AND n.state='active';
  IF NOT FOUND OR NEW.canonical_phone<>selected.canonical_phone THEN RAISE EXCEPTION 'Test dispatch source binding invalid' USING ERRCODE='23514'; END IF;
  IF NEW.state<>'prepared' OR NEW.version<>1 THEN RAISE EXCEPTION 'Test dispatch must start prepared' USING ERRCODE='23514'; END IF;
  NEW.tenant_timezone:=selected.timezone; NEW.quota_date:=(now_at AT TIME ZONE selected.timezone)::date; NEW.created_at:=now_at;
  -- Unresolved submissions from earlier dates continue to consume today's quota.
  IF (SELECT count(*) FROM public.caller_test_dispatch_intents WHERE tenant_id=NEW.tenant_id AND
    (state IN ('prepared','submitting','uncertain') OR (state IN ('accepted','ended') AND accepted_at >= (NEW.quota_date::timestamp AT TIME ZONE NEW.tenant_timezone) AND accepted_at < ((NEW.quota_date+1)::timestamp AT TIME ZONE NEW.tenant_timezone))))>=20 THEN
   RAISE EXCEPTION 'Daily test dispatch quota exhausted' USING ERRCODE='23514'; END IF;
 ELSE
  IF (NEW.id,NEW.public_id,NEW.tenant_id,NEW.test_number_id,NEW.release_artifact_id,NEW.provider_account_id,NEW.reservation_id,NEW.canonical_phone,NEW.request_key,NEW.request_hash,NEW.tenant_timezone,NEW.created_at)
   IS DISTINCT FROM (OLD.id,OLD.public_id,OLD.tenant_id,OLD.test_number_id,OLD.release_artifact_id,OLD.provider_account_id,OLD.reservation_id,OLD.canonical_phone,OLD.request_key,OLD.request_hash,OLD.tenant_timezone,OLD.created_at) THEN
   RAISE EXCEPTION 'Test dispatch source identity is immutable' USING ERRCODE='23514'; END IF;
  IF NOT ((OLD.state='prepared' AND NEW.state IN ('submitting','canceled')) OR
    (OLD.state IN ('submitting','uncertain') AND NEW.state IN ('uncertain','accepted','ended','rejected') AND OLD.state<>NEW.state) OR
    (OLD.state='accepted' AND NEW.state='ended')) THEN
   RAISE EXCEPTION 'Invalid test dispatch transition' USING ERRCODE='23514'; END IF;
  IF OLD.accepted_at IS NOT NULL AND (NEW.accepted_at,NEW.provider_call_ref) IS DISTINCT FROM (OLD.accepted_at,OLD.provider_call_ref) THEN
   RAISE EXCEPTION 'Test dispatch acceptance binding is immutable' USING ERRCODE='23514'; END IF;
  NEW.quota_date:=CASE WHEN NEW.accepted_at IS NOT NULL THEN (NEW.accepted_at AT TIME ZONE NEW.tenant_timezone)::date ELSE OLD.quota_date END;
  NEW.version:=OLD.version+1;
 END IF;
 IF NEW.accepted_at>now_at OR NEW.ended_at>now_at THEN RAISE EXCEPTION 'Test dispatch evidence cannot be in the future' USING ERRCODE='23514'; END IF;
 NEW.updated_at:=now_at;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_test_dispatch_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_test_dispatch_intents
 FOR EACH ROW EXECUTE FUNCTION public.guard_test_dispatch_intent();
CREATE TRIGGER caller_test_dispatch_no_truncate BEFORE TRUNCATE ON public.caller_test_dispatch_intents
 FOR EACH STATEMENT EXECUTE FUNCTION public.guard_test_dispatch_intent();
COMMENT ON TABLE public.caller_test_dispatch_intents IS 'Test-only durable dispatch intent; never updates production targets or attempts. Preparation is not ownership proof or dispatch authority. Final sender must verify number ownership, policy, shared capacity and provider readiness. Unknown prior-day submissions remain in daily quota; pre-accept rejection/proven unsent cancellation release it.';
