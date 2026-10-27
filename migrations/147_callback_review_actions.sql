SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_callback_review_actions (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 runtime_binding_id bigint NOT NULL,
 follow_up_task_id bigint NOT NULL,
 reason text NOT NULL CHECK(reason IN ('attempt_limit_reached','campaign_ended','campaign_ends_before_eligibility')),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(tenant_id,runtime_binding_id), UNIQUE(tenant_id,follow_up_task_id),
 FOREIGN KEY(runtime_binding_id,tenant_id) REFERENCES public.caller_runtime_release_bindings(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(follow_up_task_id,tenant_id) REFERENCES public.follow_up_tasks(id,tenant_id) ON DELETE RESTRICT
);
CREATE FUNCTION public.guard_callback_review_action() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Callback review provenance is immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 PERFORM b.id FROM public.caller_runtime_release_bindings b
 JOIN public.caller_dispatch_intents d ON d.id=b.dispatch_id AND d.tenant_id=b.tenant_id
 JOIN public.call_sessions s ON s.id=b.call_session_id AND s.tenant_id=b.tenant_id
 JOIN public.calls c ON c.id=s.call_id AND c.tenant_id=s.tenant_id
 JOIN public.customers person ON person.id=d.customer_id AND person.tenant_id=d.tenant_id
 JOIN public.follow_up_tasks task ON task.id=NEW.follow_up_task_id AND task.tenant_id=b.tenant_id
 WHERE b.id=NEW.runtime_binding_id AND b.tenant_id=NEW.tenant_id
 AND d.state='accepted' AND s.status='active' AND s.ended_at IS NULL
 AND c.status='in_progress' AND c.ended_at IS NULL AND c.direction='outbound' AND c.provider_call_id=d.provider_call_ref
 AND person.identity_revision=d.identity_revision AND person.archived_at IS NULL
 AND task.customer_id=d.customer_id AND task.customer_identity_revision=d.identity_revision
 AND task.created_at>=d.accepted_at AND task.call_id IS NULL AND task.case_id IS NULL AND task.lead_id IS NULL
 FOR SHARE OF b,d,s,c,person,task;
 IF NOT FOUND THEN RAISE EXCEPTION 'Callback review task must match its active bound call and contact' USING ERRCODE='23514'; END IF;
 NEW.created_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER caller_callback_review_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_callback_review_actions FOR EACH ROW EXECUTE FUNCTION public.guard_callback_review_action();
