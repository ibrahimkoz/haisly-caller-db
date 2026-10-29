SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_inbound_greeting_pins (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 inbound_binding_id bigint NOT NULL,
 agent_config_version_id bigint NOT NULL,
 reservation_id bigint NOT NULL,
 config_snapshot jsonb NOT NULL CHECK(jsonb_typeof(config_snapshot)='object'),
 locale text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(tenant_id,inbound_binding_id), UNIQUE(tenant_id,reservation_id),
 FOREIGN KEY(inbound_binding_id,tenant_id) REFERENCES public.caller_inbound_bindings(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(agent_config_version_id,tenant_id) REFERENCES public.agent_config_versions(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(reservation_id,tenant_id) REFERENCES public.billing_reservations(id,tenant_id) ON DELETE RESTRICT
);
CREATE FUNCTION public.guard_inbound_greeting_pin() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE selected record;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Inbound greeting pin is immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id,0));
 SELECT v.config_snapshot,t.locale INTO selected FROM public.caller_inbound_bindings b
 JOIN public.call_sessions s ON s.id=b.call_session_id AND s.tenant_id=b.tenant_id
 JOIN public.calls c ON c.id=b.call_id AND c.tenant_id=b.tenant_id
 JOIN public.agent_config_versions v ON v.id=NEW.agent_config_version_id AND v.tenant_id=b.tenant_id AND v.tenant_environment_id=b.tenant_environment_id
 JOIN public.agent_config_bindings config ON config.active_version_id=v.id AND config.ai_agent_id=v.ai_agent_id AND config.tenant_id=v.tenant_id AND config.tenant_environment_id=v.tenant_environment_id
 JOIN public.ai_agents a ON a.id=v.ai_agent_id AND a.tenant_id=v.tenant_id
 JOIN public.routing_rules route ON route.ai_agent_id=a.id AND route.tenant_id=a.tenant_id AND route.phone_number_id=b.receiving_phone_number_id
 JOIN public.billing_reservations r ON r.id=NEW.reservation_id AND r.tenant_id=b.tenant_id
 JOIN public.tenants t ON t.id=b.tenant_id
 WHERE b.id=NEW.inbound_binding_id AND b.tenant_id=NEW.tenant_id
  AND s.status='active' AND s.ended_at IS NULL AND s.call_id=c.id AND s.tenant_environment_id=b.tenant_environment_id
  AND c.status='in_progress' AND c.direction='inbound' AND c.ended_at IS NULL AND c.provider_call_id=b.provider_call_ref
  AND c.phone_number_id=b.receiving_phone_number_id
  AND v.status='published' AND v.archived_at IS NULL AND a.status='active' AND route.status='active' AND route.match_expression IS NULL
  AND r.state='held' AND r.purpose='inbound' AND r.campaign_id IS NULL AND r.reference_key=b.public_id
  AND t.status='active' AND t.deleted_at IS NULL
 LIMIT 1 FOR SHARE OF b,s,c,v,config,a,route,r,t;
 IF NOT FOUND OR jsonb_typeof(selected.config_snapshot->'greeting_message') IS DISTINCT FROM 'string'
  OR jsonb_typeof(selected.config_snapshot->'instructions') IS DISTINCT FROM 'string'
  OR btrim(selected.config_snapshot->>'greeting_message')='' OR btrim(selected.config_snapshot->>'instructions')='' THEN
  RAISE EXCEPTION 'Inbound greeting pin does not match funded active configuration' USING ERRCODE='23514';
 END IF;
 NEW.config_snapshot:=selected.config_snapshot;
 NEW.locale:=selected.locale;
 NEW.created_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER caller_inbound_greeting_pin_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_inbound_greeting_pins FOR EACH ROW EXECUTE FUNCTION public.guard_inbound_greeting_pin();
COMMENT ON TABLE public.caller_inbound_greeting_pins IS 'Immutable funded greeting configuration only, not quota, provider-start, recording or disclosure authorization.';
