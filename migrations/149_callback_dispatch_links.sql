SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_callback_dispatch_links (
 tenant_id bigint NOT NULL,
 callback_id bigint NOT NULL,
 dispatch_id bigint NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(tenant_id,dispatch_id),
 FOREIGN KEY(callback_id,tenant_id) REFERENCES public.caller_callback_plans(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(dispatch_id,tenant_id) REFERENCES public.caller_dispatch_intents(id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_callback_dispatch_lookup ON public.caller_callback_dispatch_links(tenant_id,callback_id);
CREATE FUNCTION public.guard_callback_dispatch_link() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE plan public.caller_callback_plans%ROWTYPE; source public.caller_dispatch_intents%ROWTYPE; attempt public.caller_dispatch_intents%ROWTYPE;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Callback dispatch binding is immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 SELECT * INTO plan FROM public.caller_callback_plans WHERE id=NEW.callback_id AND tenant_id=NEW.tenant_id FOR UPDATE;
 SELECT * INTO source FROM public.caller_dispatch_intents WHERE id=plan.source_dispatch_id AND tenant_id=NEW.tenant_id FOR SHARE;
 SELECT * INTO attempt FROM public.caller_dispatch_intents WHERE id=NEW.dispatch_id AND tenant_id=NEW.tenant_id FOR SHARE;
 IF plan.id IS NULL OR source.id IS NULL OR attempt.id IS NULL OR plan.state<>'pending' OR attempt.state<>'prepared'
  OR attempt.id=source.id OR attempt.target_id<>plan.target_id OR attempt.snapshot_id<>source.snapshot_id
  OR attempt.customer_id<>source.customer_id OR attempt.identity_revision<>source.identity_revision
  OR source.ended_at IS NULL OR source.ended_at+interval '15 minutes'>clock_timestamp()
  OR clock_timestamp()<plan.due_at OR clock_timestamp()>=plan.window_ends_at THEN
  RAISE EXCEPTION 'Callback dispatch requires its due plan and completed source cooldown' USING ERRCODE='23514';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.telephony_provider_accounts a JOIN public.telephony_provider_accounts b ON b.tenant_id=a.tenant_id AND b.tenant_environment_id=a.tenant_environment_id
  WHERE a.id=source.provider_account_id AND b.id=attempt.provider_account_id AND a.tenant_id=NEW.tenant_id) THEN
  RAISE EXCEPTION 'Callback dispatch environment differs from its source' USING ERRCODE='23514';
 END IF;
 IF EXISTS(SELECT 1 FROM public.caller_callback_dispatch_links l JOIN public.caller_dispatch_intents d ON d.id=l.dispatch_id AND d.tenant_id=l.tenant_id
  WHERE l.tenant_id=NEW.tenant_id AND l.callback_id=NEW.callback_id AND d.state NOT IN ('rejected','canceled')) THEN
  RAISE EXCEPTION 'Callback already has an unresolved or accepted dispatch' USING ERRCODE='23514';
 END IF;
 NEW.created_at:=clock_timestamp();
 RETURN NEW;
END $$;
CREATE TRIGGER caller_callback_dispatch_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_callback_dispatch_links FOR EACH ROW EXECUTE FUNCTION public.guard_callback_dispatch_link();
CREATE FUNCTION public.guard_callback_submission_window() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.state='submitting' AND OLD.state IS DISTINCT FROM NEW.state THEN
  PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
  IF EXISTS(SELECT 1 FROM public.caller_callback_dispatch_links WHERE tenant_id=NEW.tenant_id AND dispatch_id=NEW.id)
   AND NOT EXISTS(SELECT 1 FROM public.caller_callback_dispatch_links l JOIN public.caller_callback_plans p ON p.id=l.callback_id AND p.tenant_id=l.tenant_id
    WHERE l.tenant_id=NEW.tenant_id AND l.dispatch_id=NEW.id AND p.state='pending' AND p.due_at<=clock_timestamp() AND p.window_ends_at>clock_timestamp()) THEN
   RAISE EXCEPTION 'Callback plan changed or start window expired before submission' USING ERRCODE='23514';
  END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_callback_submission_guard BEFORE UPDATE ON public.caller_dispatch_intents FOR EACH ROW EXECUTE FUNCTION public.guard_callback_submission_window();
