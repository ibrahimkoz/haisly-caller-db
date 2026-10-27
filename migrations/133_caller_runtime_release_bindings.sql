-- Production outbound session identity. Test/inbound bindings have separate
-- eligibility requirements and cannot bypass this dispatch correlation.
SET LOCAL lock_timeout = '5s';
CREATE TABLE public.caller_runtime_release_bindings (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  call_session_id bigint NOT NULL,
  release_artifact_id bigint NOT NULL,
  dispatch_id bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (tenant_id, call_session_id),
  UNIQUE (tenant_id, dispatch_id),
  FOREIGN KEY (call_session_id, tenant_id) REFERENCES public.call_sessions(id, tenant_id) ON DELETE RESTRICT,
  FOREIGN KEY (release_artifact_id, tenant_id) REFERENCES public.caller_release_artifacts(id, tenant_id) ON DELETE RESTRICT,
  FOREIGN KEY (dispatch_id, tenant_id) REFERENCES public.caller_dispatch_intents(id, tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_runtime_release_artifact_idx ON public.caller_runtime_release_bindings(tenant_id, release_artifact_id);
CREATE FUNCTION public.caller_guard_runtime_release_binding() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE matched boolean;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW IS DISTINCT FROM OLD THEN
      RAISE EXCEPTION 'Runtime release binding is immutable' USING ERRCODE='23514';
    END IF;
    RETURN NEW;
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:' || NEW.tenant_id, 0));
  SELECT true INTO matched
    FROM public.call_sessions s
    JOIN public.calls c ON c.id=s.call_id AND c.tenant_id=s.tenant_id
    JOIN public.caller_dispatch_intents d ON d.id=NEW.dispatch_id AND d.tenant_id=s.tenant_id
    JOIN public.caller_release_artifacts r ON r.id=NEW.release_artifact_id AND r.tenant_id=s.tenant_id
    JOIN public.caller_campaign_snapshots snap ON snap.id=r.snapshot_id AND snap.tenant_id=s.tenant_id
    JOIN public.agent_config_versions v ON v.id=s.agent_config_version_id AND v.tenant_id=s.tenant_id
    JOIN public.customers person ON person.id=d.customer_id AND person.tenant_id=s.tenant_id
    WHERE s.id=NEW.call_session_id AND s.tenant_id=NEW.tenant_id
      AND s.status IN ('initiated','active') AND s.ended_at IS NULL
      AND c.direction='outbound' AND c.status IN ('ringing','in_progress') AND c.ended_at IS NULL
      AND d.state='accepted' AND c.provider_call_id=d.provider_call_ref
      AND c.phone_number_id=d.outbound_phone_number_id AND r.outbound_phone_number_id=d.outbound_phone_number_id
      AND r.snapshot_id=d.snapshot_id AND r.tenant_environment_id=s.tenant_environment_id
      AND v.tenant_environment_id=s.tenant_environment_id AND v.ai_agent_id=s.ai_agent_id AND c.ai_agent_id=s.ai_agent_id
      AND v.public_id::text=snap.document->'settings'->>'agent_version_public_id'
      AND person.identity_revision=d.identity_revision AND person.archived_at IS NULL
    FOR SHARE OF s,c,d,r,snap,v,person;
  IF NOT COALESCE(matched,false) THEN
    RAISE EXCEPTION 'Runtime release does not match accepted dispatch and call identity' USING ERRCODE='23514';
  END IF;
  NEW.created_at := clock_timestamp();
  RETURN NEW;
END;
$$;
CREATE TRIGGER caller_runtime_release_binding_guard BEFORE INSERT OR UPDATE
ON public.caller_runtime_release_bindings FOR EACH ROW EXECUTE FUNCTION public.caller_guard_runtime_release_binding();
