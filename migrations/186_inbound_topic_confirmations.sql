SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_inbound_topic_confirmations (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 inbound_binding_id bigint NOT NULL,
 dispatch_id bigint NOT NULL,
 provider_event_key text NOT NULL CHECK(length(btrim(provider_event_key)) BETWEEN 1 AND 200),
 request_hash text NOT NULL CHECK(request_hash ~ '^[a-f0-9]{64}$'),
 decision text NOT NULL CHECK(decision IN ('confirmed','rejected')),
 occurred_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(tenant_id,inbound_binding_id,provider_event_key),
 UNIQUE(tenant_id,inbound_binding_id,occurred_at),
 FOREIGN KEY(inbound_binding_id,tenant_id) REFERENCES public.caller_inbound_bindings(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(dispatch_id,tenant_id) REFERENCES public.caller_dispatch_intents(id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_inbound_topic_latest_idx ON public.caller_inbound_topic_confirmations(tenant_id,inbound_binding_id,occurred_at DESC,id DESC);
CREATE FUNCTION public.guard_inbound_topic_confirmation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Inbound topic confirmation is immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id,0));
 PERFORM b.id FROM public.caller_inbound_bindings b
 JOIN public.call_sessions s ON s.id=b.call_session_id AND s.tenant_id=b.tenant_id
 JOIN public.calls c ON c.id=b.call_id AND c.tenant_id=b.tenant_id
 JOIN public.customers customer ON customer.id=b.customer_id AND customer.tenant_id=b.tenant_id
 JOIN public.caller_dispatch_intents d ON d.id=NEW.dispatch_id AND d.tenant_id=b.tenant_id
 JOIN public.telephony_provider_accounts p ON p.id=d.provider_account_id AND p.tenant_id=d.tenant_id
 WHERE b.id=NEW.inbound_binding_id AND b.tenant_id=NEW.tenant_id
  AND b.caller_phone IS NOT NULL AND customer.archived_at IS NULL
  AND customer.identity_revision=b.identity_revision AND customer.canonical_phone=b.caller_phone
  AND s.call_id=b.call_id AND s.tenant_environment_id=b.tenant_environment_id AND s.status='active' AND s.ended_at IS NULL
  AND c.direction='inbound' AND c.status='in_progress' AND c.ended_at IS NULL
  AND c.provider_call_id=b.provider_call_ref AND c.phone_number_id=b.receiving_phone_number_id
  AND d.customer_id=b.customer_id AND d.identity_revision=b.identity_revision AND d.canonical_phone=b.caller_phone
  AND p.tenant_environment_id=b.tenant_environment_id AND d.state IN ('accepted','ended')
  AND d.accepted_at BETWEEN clock_timestamp()-interval '30 days' AND NEW.occurred_at
  AND NEW.occurred_at BETWEEN b.created_at AND clock_timestamp()
 FOR SHARE OF b,s,c,customer,d,p;
 IF NOT FOUND THEN RAISE EXCEPTION 'Inbound topic evidence does not match active recognized call and recent campaign' USING ERRCODE='23514'; END IF;
 NEW.created_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER caller_inbound_topic_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_inbound_topic_confirmations FOR EACH ROW EXECUTE FUNCTION public.guard_inbound_topic_confirmation();
COMMENT ON TABLE public.caller_inbound_topic_confirmations IS 'Trusted adapter human topic responses, never model inference. Latest occurred_at wins; rejection clears selection. Not general identity, recording consent, survey resume or dispatch authority.';
