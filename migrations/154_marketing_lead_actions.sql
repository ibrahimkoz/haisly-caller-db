SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_marketing_lead_actions (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 target_id bigint NOT NULL,
 snapshot_id bigint NOT NULL,
 result_id bigint NOT NULL,
 confirmation_id bigint NOT NULL,
 team_id bigint NOT NULL,
 lead_id bigint NOT NULL,
 follow_up_task_id bigint NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,target_id,snapshot_id),
 UNIQUE(tenant_id,lead_id), UNIQUE(tenant_id,follow_up_task_id), UNIQUE(tenant_id,confirmation_id),
 FOREIGN KEY(target_id,tenant_id) REFERENCES public.caller_campaign_targets(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(snapshot_id,tenant_id) REFERENCES public.caller_campaign_snapshots(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(result_id,tenant_id) REFERENCES public.caller_marketing_result_revisions(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(confirmation_id,tenant_id) REFERENCES public.caller_marketing_interest_confirmations(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(team_id,tenant_id) REFERENCES public.caller_teams(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(lead_id,tenant_id) REFERENCES public.leads(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(follow_up_task_id,tenant_id) REFERENCES public.follow_up_tasks(id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_marketing_action_result ON public.caller_marketing_lead_actions(tenant_id,result_id);
CREATE INDEX caller_marketing_action_team ON public.caller_marketing_lead_actions(tenant_id,team_id);
CREATE INDEX caller_marketing_action_snapshot ON public.caller_marketing_lead_actions(tenant_id,snapshot_id);
CREATE FUNCTION public.guard_marketing_lead_action() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Marketing action provenance is immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 PERFORM r.id FROM public.caller_marketing_result_revisions r
 JOIN public.caller_marketing_interest_confirmations proof ON proof.result_id=r.id AND proof.tenant_id=r.tenant_id
 JOIN public.caller_runtime_release_bindings b ON b.id=r.runtime_binding_id AND b.tenant_id=r.tenant_id
 JOIN public.caller_dispatch_intents d ON d.id=b.dispatch_id AND d.tenant_id=b.tenant_id
 JOIN public.call_sessions session ON session.id=b.call_session_id AND session.tenant_id=b.tenant_id
 JOIN public.caller_campaign_snapshots snap ON snap.id=r.snapshot_id AND snap.tenant_id=r.tenant_id
 JOIN public.customers person ON person.id=d.customer_id AND person.tenant_id=d.tenant_id
 JOIN public.caller_teams team ON team.id=NEW.team_id AND team.tenant_id=r.tenant_id
 JOIN public.leads lead ON lead.id=NEW.lead_id AND lead.tenant_id=r.tenant_id
 JOIN public.follow_up_tasks task ON task.id=NEW.follow_up_task_id AND task.tenant_id=r.tenant_id
 WHERE r.id=NEW.result_id AND r.tenant_id=NEW.tenant_id AND r.target_id=NEW.target_id AND r.snapshot_id=NEW.snapshot_id
 AND proof.id=NEW.confirmation_id AND proof.decision='granted' AND proof.runtime_binding_id=r.runtime_binding_id
 AND r.outcome='interested' AND r.connection_outcome='human' AND r.request IS NOT NULL
 AND d.state IN ('accepted','ended') AND person.identity_revision=d.identity_revision AND person.archived_at IS NULL
 AND snap.document->>'campaign_type'='marketing' AND snap.document->'settings'->>'marketing_follow_up_mode'='automatic'
 AND snap.document->'settings'->>'marketing_team_public_id'=team.public_id::text AND team.archived_at IS NULL
 AND lead.customer_id=d.customer_id AND lead.customer_identity_revision=d.identity_revision AND lead.source_call_id=session.call_id AND lead.source_case_id IS NULL
 AND task.customer_id=d.customer_id AND task.customer_identity_revision=d.identity_revision AND task.call_id=session.call_id AND task.case_id IS NULL AND task.lead_id=lead.id
 AND task.assigned_user_id IS NOT DISTINCT FROM lead.owner_user_id
 AND lead.created_at>=proof.resolved_at AND task.created_at>=proof.resolved_at
 AND NOT EXISTS(SELECT 1 FROM public.caller_marketing_result_revisions later WHERE later.tenant_id=r.tenant_id AND later.target_id=r.target_id AND later.snapshot_id=r.snapshot_id AND later.version>r.version)
 FOR SHARE OF r,proof,b,d,session,snap,person,team,lead,task;
 IF NOT FOUND THEN RAISE EXCEPTION 'Marketing lead and task require current confirmed interest and matching captured team/identity' USING ERRCODE='23514'; END IF;
 NEW.created_at:=clock_timestamp(); RETURN NEW;
END $$;
CREATE TRIGGER caller_marketing_action_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_marketing_lead_actions FOR EACH ROW EXECUTE FUNCTION public.guard_marketing_lead_action();
