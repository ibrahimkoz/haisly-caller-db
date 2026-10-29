SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_inbound_bindings (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 tenant_environment_id bigint NOT NULL,
 call_session_id bigint NOT NULL,
 call_id bigint NOT NULL,
 provider_account_id bigint NOT NULL,
 receiving_phone_number_id bigint NOT NULL,
 provider_call_ref text NOT NULL CHECK(length(btrim(provider_call_ref)) BETWEEN 1 AND 200),
 provider_event_key text NOT NULL CHECK(length(btrim(provider_event_key)) BETWEEN 1 AND 200),
 request_hash text NOT NULL CHECK(request_hash ~ '^[a-f0-9]{64}$'),
 caller_phone text CHECK(caller_phone ~ '^\+[1-9][0-9]{6,14}$'),
 customer_id bigint,
 identity_revision integer CHECK(identity_revision>0),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,call_session_id), UNIQUE(tenant_id,call_id),
 UNIQUE(tenant_id,provider_account_id,provider_event_key), UNIQUE(tenant_id,provider_account_id,provider_call_ref),
 CHECK((customer_id IS NULL)=(identity_revision IS NULL)),
 CHECK(caller_phone IS NOT NULL OR customer_id IS NULL),
 FOREIGN KEY(tenant_environment_id,tenant_id) REFERENCES public.tenant_environments(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(call_session_id,tenant_id) REFERENCES public.call_sessions(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(call_id,tenant_id) REFERENCES public.calls(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(provider_account_id,tenant_id) REFERENCES public.telephony_provider_accounts(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(receiving_phone_number_id,tenant_id) REFERENCES public.phone_numbers(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(customer_id,tenant_id) REFERENCES public.customers(id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_inbound_identity_history_idx ON public.caller_inbound_bindings(tenant_id,customer_id,identity_revision,id DESC) WHERE customer_id IS NOT NULL;
CREATE FUNCTION public.guard_inbound_call_binding() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Inbound call binding is immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id,0));
 PERFORM s.id FROM public.call_sessions s
 JOIN public.calls c ON c.id=s.call_id AND c.tenant_id=s.tenant_id
 JOIN public.phone_numbers phone ON phone.id=c.phone_number_id AND phone.tenant_id=c.tenant_id
 JOIN public.telephony_provider_accounts p ON p.id=NEW.provider_account_id AND p.tenant_id=s.tenant_id
 JOIN public.tenant_environments e ON e.id=s.tenant_environment_id AND e.tenant_id=s.tenant_id
 WHERE s.id=NEW.call_session_id AND s.tenant_id=NEW.tenant_id AND s.tenant_environment_id=NEW.tenant_environment_id
  AND s.status='active' AND s.ended_at IS NULL AND c.id=NEW.call_id AND c.direction='inbound'
  AND c.status='in_progress' AND c.ended_at IS NULL AND c.provider_call_id=NEW.provider_call_ref
  AND phone.id=NEW.receiving_phone_number_id AND phone.status='active'
  AND p.tenant_environment_id=NEW.tenant_environment_id AND p.status='active' AND e.status='active'
 FOR SHARE OF s,c,phone,p,e;
 IF NOT FOUND THEN RAISE EXCEPTION 'Inbound provider session binding mismatch' USING ERRCODE='23514'; END IF;
 NEW.customer_id:=NULL;NEW.identity_revision:=NULL;
 IF NEW.caller_phone IS NOT NULL THEN
  SELECT id,identity_revision INTO NEW.customer_id,NEW.identity_revision FROM public.customers
   WHERE tenant_id=NEW.tenant_id AND canonical_phone=NEW.caller_phone AND archived_at IS NULL FOR SHARE;
 END IF;
 NEW.created_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER caller_inbound_binding_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_inbound_bindings FOR EACH ROW EXECUTE FUNCTION public.guard_inbound_call_binding();
COMMENT ON TABLE public.caller_inbound_bindings IS 'Authenticated adapter correlation only. Recognized caller ID is not identity/topic confirmation and grants no personal disclosure, survey resume, budget or calling authority.';
