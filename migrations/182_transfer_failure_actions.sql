SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_transfer_failure_actions (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 transfer_attempt_id bigint NOT NULL,
 follow_up_task_id bigint NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(tenant_id,transfer_attempt_id), UNIQUE(tenant_id,follow_up_task_id),
 FOREIGN KEY(transfer_attempt_id,tenant_id) REFERENCES public.caller_transfer_attempts(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(follow_up_task_id,tenant_id) REFERENCES public.follow_up_tasks(id,tenant_id) ON DELETE RESTRICT
);
CREATE FUNCTION public.guard_transfer_failure_action() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE matched boolean;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Transfer failure provenance is immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id,0));
 SELECT true INTO matched FROM public.caller_transfer_attempts a
 JOIN public.caller_transfer_event_receipts r ON r.transfer_attempt_id=a.id AND r.tenant_id=a.tenant_id
 JOIN public.caller_dispatch_intents d ON d.id=r.dispatch_id AND d.tenant_id=r.tenant_id
 JOIN public.customers c ON c.id=d.customer_id AND c.tenant_id=d.tenant_id
 JOIN public.follow_up_tasks f ON f.id=NEW.follow_up_task_id AND f.tenant_id=a.tenant_id
 WHERE a.id=NEW.transfer_attempt_id AND a.tenant_id=NEW.tenant_id AND a.status='failed'
  AND r.outcome='failed' AND r.result_status='failed' AND NOT r.result_conflict_hold
  AND f.case_id IS NULL AND f.lead_id IS NULL AND f.created_at>=a.reserved_at
  AND ((c.identity_revision=d.identity_revision AND c.archived_at IS NULL AND f.customer_id=d.customer_id AND f.customer_identity_revision=d.identity_revision AND f.call_id=a.call_id)
   OR ((c.identity_revision<>d.identity_revision OR c.archived_at IS NOT NULL) AND f.customer_id IS NULL AND f.customer_identity_revision IS NULL AND f.call_id IS NULL))
 LIMIT 1 FOR SHARE OF a,r,d,c,f;
 IF NOT COALESCE(matched,false) THEN RAISE EXCEPTION 'Transfer follow-up does not match failure evidence and contact identity' USING ERRCODE='23514'; END IF;
 NEW.created_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER caller_transfer_failure_action_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_transfer_failure_actions FOR EACH ROW EXECUTE FUNCTION public.guard_transfer_failure_action();
