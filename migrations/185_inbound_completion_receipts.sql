SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_inbound_completions (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 inbound_binding_id bigint NOT NULL,
 provider_account_id bigint NOT NULL,
 provider_event_key text NOT NULL CHECK(length(btrim(provider_event_key)) BETWEEN 1 AND 200),
 request_hash text NOT NULL CHECK(request_hash ~ '^[a-f0-9]{64}$'),
 conversation_kind text NOT NULL CHECK(conversation_kind IN ('human','nonhuman')),
 caller_phone text,
 completed_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(tenant_id,inbound_binding_id),UNIQUE(tenant_id,provider_account_id,provider_event_key),
 FOREIGN KEY(inbound_binding_id,tenant_id) REFERENCES public.caller_inbound_bindings(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(provider_account_id,tenant_id) REFERENCES public.telephony_provider_accounts(id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_inbound_completed_phone_idx ON public.caller_inbound_completions(tenant_id,caller_phone,completed_at DESC) WHERE conversation_kind='human' AND caller_phone IS NOT NULL;
CREATE INDEX caller_inbound_binding_phone_idx ON public.caller_inbound_bindings(tenant_id,caller_phone,id) WHERE caller_phone IS NOT NULL;
CREATE FUNCTION public.guard_inbound_completion() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE binding public.caller_inbound_bindings%ROWTYPE;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Inbound completion evidence is immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id,0));
 SELECT * INTO binding FROM public.caller_inbound_bindings WHERE id=NEW.inbound_binding_id AND tenant_id=NEW.tenant_id FOR SHARE;
 IF NOT FOUND OR binding.provider_account_id<>NEW.provider_account_id THEN RAISE EXCEPTION 'Inbound completion provider mismatch' USING ERRCODE='23514'; END IF;
 PERFORM c.id FROM public.calls c JOIN public.call_sessions s ON s.call_id=c.id AND s.tenant_id=c.tenant_id
 WHERE c.id=binding.call_id AND c.tenant_id=NEW.tenant_id AND c.direction='inbound' AND c.provider_call_id=binding.provider_call_ref
  AND c.phone_number_id=binding.receiving_phone_number_id AND c.status IN ('completed','failed','no_answer','busy','canceled')
  AND (NEW.conversation_kind='nonhuman' OR c.status='completed')
  AND s.id=binding.call_session_id AND s.tenant_environment_id=binding.tenant_environment_id AND s.status IN ('completed','failed','cancelled')
  AND c.ended_at=NEW.completed_at AND s.ended_at=NEW.completed_at AND c.started_at<=NEW.completed_at AND s.started_at<=NEW.completed_at
  AND binding.created_at<=NEW.completed_at
 FOR SHARE OF c,s;
 IF NOT FOUND OR NEW.completed_at>clock_timestamp() THEN RAISE EXCEPTION 'Inbound completion does not match finalized call' USING ERRCODE='23514'; END IF;
 NEW.caller_phone:=binding.caller_phone;
 NEW.created_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER caller_inbound_completion_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_inbound_completions FOR EACH ROW EXECUTE FUNCTION public.guard_inbound_completion();
