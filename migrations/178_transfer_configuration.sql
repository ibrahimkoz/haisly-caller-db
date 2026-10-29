SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_transfer_team_policies (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 tenant_environment_id bigint NOT NULL,
 team_id bigint NOT NULL,
 timezone text NOT NULL CHECK(length(timezone) BETWEEN 1 AND 100),
 hours jsonb NOT NULL CHECK(jsonb_typeof(hours)='array' AND jsonb_array_length(hours) BETWEEN 1 AND 14 AND octet_length(hours::text)<=131072),
 capacity integer NOT NULL CHECK(capacity BETWEEN 1 AND 100),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 archived_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,tenant_environment_id,team_id),
 FOREIGN KEY(tenant_environment_id,tenant_id) REFERENCES public.tenant_environments(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(team_id,tenant_id) REFERENCES public.caller_teams(id,tenant_id) ON DELETE RESTRICT
);
CREATE TABLE public.caller_transfer_destinations (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 team_policy_id bigint NOT NULL,
 name text NOT NULL CHECK(length(btrim(name)) BETWEEN 1 AND 160),
 kind text NOT NULL CHECK(kind IN ('phone','sip')),
 address text NOT NULL CHECK(length(address) BETWEEN 1 AND 320),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 archived_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK((kind='phone' AND address ~ '^\+[1-9][0-9]{6,14}$') OR
       (kind='sip' AND address ~ '^sips?:[A-Za-z0-9_.+-]{1,64}@[A-Za-z0-9][A-Za-z0-9.-]*(:[0-9]{1,5})?$')),
 UNIQUE(id,tenant_id),
 FOREIGN KEY(team_policy_id,tenant_id) REFERENCES public.caller_transfer_team_policies(id,tenant_id) ON DELETE RESTRICT
);
CREATE UNIQUE INDEX caller_transfer_destination_active_unique ON public.caller_transfer_destinations(tenant_id,team_policy_id,kind,address) WHERE archived_at IS NULL;
CREATE INDEX caller_transfer_destination_history_idx ON public.caller_transfer_destinations(tenant_id,team_policy_id,id DESC);
COMMENT ON TABLE public.caller_transfer_destinations IS 'Administrator allowlist configuration only. No ownership/provider verification evidence or transfer dispatch authorization. Runtime cannot supply arbitrary addresses.';
CREATE FUNCTION public.guard_caller_transfer_configuration() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Archive transfer configuration instead of deleting' USING ERRCODE='23514'; END IF;
 IF TG_OP='UPDATE' THEN
  IF NEW.id<>OLD.id OR NEW.public_id<>OLD.public_id OR NEW.tenant_id<>OLD.tenant_id OR NEW.created_at<>OLD.created_at THEN
   RAISE EXCEPTION 'Transfer configuration identity is immutable' USING ERRCODE='23514'; END IF;
  IF TG_TABLE_NAME='caller_transfer_team_policies' THEN
   IF NEW.tenant_environment_id<>OLD.tenant_environment_id OR NEW.team_id<>OLD.team_id THEN
    RAISE EXCEPTION 'Transfer team scope is immutable' USING ERRCODE='23514'; END IF;
  ELSE
   IF NEW.team_policy_id<>OLD.team_policy_id THEN RAISE EXCEPTION 'Transfer destination scope is immutable' USING ERRCODE='23514'; END IF;
  END IF;
  NEW.version:=OLD.version+1;
 ELSE NEW.version:=1;
 END IF;
 IF TG_TABLE_NAME='caller_transfer_team_policies' THEN
  IF NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=NEW.timezone) THEN
   RAISE EXCEPTION 'Invalid transfer team timezone' USING ERRCODE='23514'; END IF;
 END IF;
 NEW.updated_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER caller_transfer_team_policy_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_transfer_team_policies
 FOR EACH ROW EXECUTE FUNCTION public.guard_caller_transfer_configuration();
CREATE TRIGGER caller_transfer_destination_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_transfer_destinations
 FOR EACH ROW EXECUTE FUNCTION public.guard_caller_transfer_configuration();
