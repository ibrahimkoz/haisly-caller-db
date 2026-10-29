SET LOCAL lock_timeout='5s';
-- Storage and serialization only. Inserting a claim never authorizes REFER;
-- the service must also establish verification, human intent and budget evidence.
CREATE TABLE public.caller_transfer_attempts (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 tenant_environment_id bigint NOT NULL,
 call_id bigint NOT NULL,
 team_policy_id bigint NOT NULL,
 destination_id bigint NOT NULL,
 policy_version integer NOT NULL CHECK(policy_version>0),
 destination_version integer NOT NULL CHECK(destination_version>0),
 request_key uuid NOT NULL,
 destination_kind text NOT NULL CHECK(destination_kind IN ('phone','sip')),
 destination_address text NOT NULL CHECK(length(destination_address) BETWEEN 1 AND 320),
 status text NOT NULL DEFAULT 'reserved' CHECK(status IN ('reserved','pending','uncertain','connected','failed','completed')),
 conflict_hold boolean NOT NULL DEFAULT false,
 capacity_held boolean GENERATED ALWAYS AS (conflict_hold OR status NOT IN ('failed','completed')) STORED,
 reserved_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 submitted_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,request_key),
 CHECK((status='reserved')=(submitted_at IS NULL)),
 CHECK(submitted_at IS NULL OR submitted_at>=reserved_at),
 FOREIGN KEY(call_id,tenant_id) REFERENCES public.calls(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(tenant_environment_id,tenant_id) REFERENCES public.tenant_environments(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(team_policy_id,tenant_id) REFERENCES public.caller_transfer_team_policies(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(destination_id,tenant_id) REFERENCES public.caller_transfer_destinations(id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_transfer_attempt_capacity_idx ON public.caller_transfer_attempts(tenant_id,team_policy_id) WHERE capacity_held;
CREATE INDEX caller_transfer_attempt_call_idx ON public.caller_transfer_attempts(tenant_id,call_id,id DESC);
CREATE INDEX caller_transfer_attempt_reconcile_idx ON public.caller_transfer_attempts(tenant_id,updated_at,id) WHERE status='uncertain' OR conflict_hold;
CREATE FUNCTION public.guard_caller_transfer_attempt() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE policy public.caller_transfer_team_policies%ROWTYPE;
 target public.caller_transfer_destinations%ROWTYPE;
 call_status text;
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Transfer attempts require retention workflow' USING ERRCODE='23514'; END IF;
 -- Same lock order for every attempt, including late conflicts. Services must
 -- use READ COMMITTED and acquire call -> policy -> destination before insert.
 SELECT status INTO call_status FROM public.calls WHERE id=NEW.call_id AND tenant_id=NEW.tenant_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Transfer call missing' USING ERRCODE='23503'; END IF;
 SELECT * INTO policy FROM public.caller_transfer_team_policies WHERE id=NEW.team_policy_id AND tenant_id=NEW.tenant_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Transfer policy missing' USING ERRCODE='23503'; END IF;
 IF TG_OP='INSERT' THEN
  SELECT * INTO target FROM public.caller_transfer_destinations WHERE id=NEW.destination_id AND tenant_id=NEW.tenant_id FOR SHARE;
  IF NOT FOUND OR target.team_policy_id<>policy.id OR policy.tenant_environment_id<>NEW.tenant_environment_id THEN
   RAISE EXCEPTION 'Transfer destination scope mismatch' USING ERRCODE='23514'; END IF;
  IF NEW.status<>'reserved' OR NEW.submitted_at IS NOT NULL OR NEW.conflict_hold THEN
   RAISE EXCEPTION 'Transfer must begin reserved' USING ERRCODE='23514'; END IF;
  IF call_status<>'in_progress' OR policy.archived_at IS NOT NULL OR target.archived_at IS NOT NULL
   OR policy.version<>NEW.policy_version OR target.version<>NEW.destination_version
   OR target.kind<>NEW.destination_kind OR target.address<>NEW.destination_address THEN
   RAISE EXCEPTION 'Transfer configuration stale or inactive' USING ERRCODE='23514'; END IF;
  IF EXISTS(SELECT 1 FROM public.caller_transfer_attempts WHERE tenant_id=NEW.tenant_id AND call_id=NEW.call_id AND capacity_held) THEN
   RAISE EXCEPTION 'Call already has an occupied transfer' USING ERRCODE='23514'; END IF;
  IF (SELECT count(*) FROM public.caller_transfer_attempts WHERE tenant_id=NEW.tenant_id AND team_policy_id=NEW.team_policy_id AND capacity_held)>=policy.capacity THEN
   RAISE EXCEPTION 'Transfer team at capacity' USING ERRCODE='23514'; END IF;
  NEW.version:=1; NEW.reserved_at:=clock_timestamp();
 ELSE
  IF ROW(NEW.id,NEW.public_id,NEW.tenant_id,NEW.tenant_environment_id,NEW.call_id,NEW.team_policy_id,NEW.destination_id,NEW.policy_version,NEW.destination_version,NEW.request_key,NEW.destination_kind,NEW.destination_address,NEW.reserved_at)
    IS DISTINCT FROM ROW(OLD.id,OLD.public_id,OLD.tenant_id,OLD.tenant_environment_id,OLD.call_id,OLD.team_policy_id,OLD.destination_id,OLD.policy_version,OLD.destination_version,OLD.request_key,OLD.destination_kind,OLD.destination_address,OLD.reserved_at) THEN
   RAISE EXCEPTION 'Transfer identity and snapshot are immutable' USING ERRCODE='23514'; END IF;
  IF OLD.conflict_hold AND NOT NEW.conflict_hold THEN
   RAISE EXCEPTION 'Conflict holds require authoritative reconciliation workflow' USING ERRCODE='23514'; END IF;
  IF OLD.submitted_at IS NOT NULL AND NEW.submitted_at IS DISTINCT FROM OLD.submitted_at THEN
   RAISE EXCEPTION 'Transfer submission time is immutable' USING ERRCODE='23514'; END IF;
  IF NEW.status<>OLD.status AND NOT (
   (OLD.status='reserved' AND NEW.status='pending') OR
   (OLD.status IN ('pending','uncertain') AND NEW.status IN ('uncertain','connected','failed','completed')) OR
   (OLD.status='connected' AND NEW.status='completed')) THEN
   RAISE EXCEPTION 'Invalid transfer state transition' USING ERRCODE='23514'; END IF;
  NEW.version:=OLD.version+1;
 END IF;
 NEW.updated_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER caller_transfer_attempt_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_transfer_attempts
 FOR EACH ROW EXECUTE FUNCTION public.guard_caller_transfer_attempt();
COMMENT ON TABLE public.caller_transfer_attempts IS 'Durable transfer occupancy and immutable target snapshot. Provider dispatch, verified receipts, conflict resolution and retention require service workflows; rows alone confer no authority.';
