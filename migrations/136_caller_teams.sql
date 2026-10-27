SET LOCAL lock_timeout = '5s';
CREATE TABLE public.caller_teams (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
 name text NOT NULL CHECK(length(btrim(name)) BETWEEN 1 AND 120),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 -- Stable order bookmark, not a member FK: removing a member must not reset fairness.
 assignment_cursor bigint NOT NULL DEFAULT 0 CHECK(assignment_cursor>=0),
 assignment_updated_at timestamptz,
 archived_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(id,tenant_id)
);
CREATE UNIQUE INDEX caller_team_active_name_unique ON public.caller_teams(tenant_id,lower(btrim(name))) WHERE archived_at IS NULL;
CREATE INDEX caller_team_tenant_page_idx ON public.caller_teams(tenant_id,id);
CREATE FUNCTION public.caller_guard_team() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='INSERT' THEN
  IF NEW.version<>1 OR NEW.assignment_cursor<>0 OR NEW.assignment_updated_at IS NOT NULL THEN
   RAISE EXCEPTION 'Team must start at version one without assignments' USING ERRCODE='23514';
  END IF;
 ELSE
  IF (NEW.id,NEW.public_id,NEW.tenant_id,NEW.created_at) IS DISTINCT FROM
     (OLD.id,OLD.public_id,OLD.tenant_id,OLD.created_at) THEN
   RAISE EXCEPTION 'Team identity is immutable' USING ERRCODE='23514';
  END IF;
  IF (NEW.name,NEW.archived_at) IS DISTINCT FROM (OLD.name,OLD.archived_at) THEN
   IF NEW.version<>OLD.version+1 THEN RAISE EXCEPTION 'Team configuration version must advance' USING ERRCODE='23514'; END IF;
   NEW.updated_at := clock_timestamp();
  ELSIF NEW.version<OLD.version OR NEW.version>OLD.version+1 THEN
   RAISE EXCEPTION 'Team version cannot move backwards or skip' USING ERRCODE='23514';
  END IF;
 END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER caller_team_guard BEFORE INSERT OR UPDATE ON public.caller_teams
 FOR EACH ROW EXECUTE FUNCTION public.caller_guard_team();
CREATE TABLE public.caller_team_members (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 tenant_id bigint NOT NULL,
 team_id bigint NOT NULL,
 user_id bigint NOT NULL,
 available_for_assignment boolean NOT NULL DEFAULT true,
 removed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,team_id,user_id),
 FOREIGN KEY(team_id,tenant_id) REFERENCES public.caller_teams(id,tenant_id) ON DELETE CASCADE,
 FOREIGN KEY(user_id,tenant_id) REFERENCES public.tenant_memberships(user_id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_team_member_assignment_idx ON public.caller_team_members(tenant_id,team_id,id)
 WHERE removed_at IS NULL AND available_for_assignment;
CREATE INDEX caller_team_member_user_idx ON public.caller_team_members(tenant_id,user_id);
CREATE FUNCTION public.caller_guard_team_member() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='UPDATE' AND (NEW.id,NEW.tenant_id,NEW.team_id,NEW.user_id,NEW.created_at)
    IS DISTINCT FROM (OLD.id,OLD.tenant_id,OLD.team_id,OLD.user_id,OLD.created_at) THEN
  RAISE EXCEPTION 'Team member identity is immutable' USING ERRCODE='23514';
 END IF;
 IF NEW.removed_at IS NULL AND (TG_OP='INSERT' OR NEW.available_for_assignment OR OLD.removed_at IS NOT NULL) THEN
  PERFORM t.id FROM public.caller_teams t
   JOIN public.tenant_memberships m ON m.tenant_id=t.tenant_id AND m.user_id=NEW.user_id
   JOIN public.users u ON u.id=m.user_id
   WHERE t.id=NEW.team_id AND t.tenant_id=NEW.tenant_id AND t.archived_at IS NULL
    AND m.status='active' AND m.deleted_at IS NULL AND u.status='active' AND u.deleted_at IS NULL
   FOR SHARE OF t,m,u;
  IF NOT FOUND THEN RAISE EXCEPTION 'Team member requires an active tenant membership and team' USING ERRCODE='23514'; END IF;
 END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER caller_team_member_guard BEFORE INSERT OR UPDATE ON public.caller_team_members
 FOR EACH ROW EXECUTE FUNCTION public.caller_guard_team_member();
