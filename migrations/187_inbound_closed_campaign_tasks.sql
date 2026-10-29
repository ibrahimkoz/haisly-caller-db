SET LOCAL lock_timeout='5s';
ALTER TABLE public.caller_inbound_topic_confirmations ADD CONSTRAINT caller_inbound_topic_id_tenant_unique UNIQUE(id,tenant_id);
CREATE TABLE public.caller_inbound_follow_up_actions (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 inbound_binding_id bigint NOT NULL,
 campaign_id bigint NOT NULL,
 confirmation_id bigint NOT NULL,
 follow_up_task_id bigint NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(tenant_id,inbound_binding_id,campaign_id), UNIQUE(tenant_id,follow_up_task_id),
 FOREIGN KEY(inbound_binding_id,tenant_id) REFERENCES public.caller_inbound_bindings(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(campaign_id,tenant_id) REFERENCES public.caller_campaigns(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(confirmation_id,tenant_id) REFERENCES public.caller_inbound_topic_confirmations(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(follow_up_task_id,tenant_id) REFERENCES public.follow_up_tasks(id,tenant_id) ON DELETE RESTRICT
);
CREATE FUNCTION public.guard_inbound_follow_up_action() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Inbound follow-up provenance is immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id,0));
 PERFORM b.id FROM public.caller_inbound_bindings b
 JOIN public.caller_inbound_topic_confirmations topic ON topic.inbound_binding_id=b.id AND topic.tenant_id=b.tenant_id
 JOIN public.caller_dispatch_intents d ON d.id=topic.dispatch_id AND d.tenant_id=topic.tenant_id
 JOIN public.caller_campaigns campaign ON campaign.id=d.campaign_id AND campaign.tenant_id=d.tenant_id
 JOIN public.caller_campaign_snapshots snapshot ON snapshot.id=d.snapshot_id AND snapshot.tenant_id=d.tenant_id
 JOIN public.customers customer ON customer.id=b.customer_id AND customer.tenant_id=b.tenant_id
 JOIN public.call_sessions s ON s.id=b.call_session_id AND s.tenant_id=b.tenant_id
 JOIN public.calls c ON c.id=b.call_id AND c.tenant_id=b.tenant_id
 JOIN public.follow_up_tasks f ON f.id=NEW.follow_up_task_id AND f.tenant_id=b.tenant_id
 WHERE b.id=NEW.inbound_binding_id AND b.tenant_id=NEW.tenant_id
  AND campaign.id=NEW.campaign_id AND topic.id=NEW.confirmation_id AND topic.decision='confirmed'
  AND NOT EXISTS(SELECT 1 FROM public.caller_inbound_topic_confirmations newer WHERE newer.tenant_id=b.tenant_id AND newer.inbound_binding_id=b.id AND newer.occurred_at>topic.occurred_at)
  AND (campaign.state='canceled' OR (snapshot.document->'settings'->>'ends_at')::timestamptz<=clock_timestamp())
  AND customer.archived_at IS NULL AND customer.identity_revision=b.identity_revision AND customer.canonical_phone=b.caller_phone
  AND d.customer_id=b.customer_id AND d.identity_revision=b.identity_revision
  AND s.status='active' AND s.ended_at IS NULL AND s.call_id=c.id AND s.tenant_environment_id=b.tenant_environment_id
  AND c.direction='inbound' AND c.status='in_progress' AND c.ended_at IS NULL AND c.provider_call_id=b.provider_call_ref
  AND f.customer_id=b.customer_id AND f.customer_identity_revision=b.identity_revision AND f.call_id=b.call_id
  AND f.case_id IS NULL AND f.lead_id IS NULL AND f.created_at>=topic.created_at
 FOR SHARE OF b,topic,d,campaign,snapshot,customer,s,c,f;
 IF NOT FOUND THEN RAISE EXCEPTION 'Inbound follow-up does not match closed campaign and current topic' USING ERRCODE='23514'; END IF;
 NEW.created_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER caller_inbound_follow_up_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_inbound_follow_up_actions FOR EACH ROW EXECUTE FUNCTION public.guard_inbound_follow_up_action();
