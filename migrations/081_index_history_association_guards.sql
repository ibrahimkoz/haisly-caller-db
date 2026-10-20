-- Bound the reverse lookups used by identity association/lead-conversion guards.
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
CREATE INDEX cases_identity_call_idx ON public.cases(tenant_id,source_call_id) WHERE customer_id IS NOT NULL;
CREATE INDEX leads_identity_call_idx ON public.leads(tenant_id,source_call_id) WHERE customer_id IS NOT NULL;
CREATE INDEX follow_up_tasks_identity_call_idx ON public.follow_up_tasks(tenant_id,call_id) WHERE customer_id IS NOT NULL;
CREATE INDEX handoff_requests_identity_call_idx ON public.handoff_requests(tenant_id,call_id) WHERE customer_id IS NOT NULL;
CREATE INDEX workflow_runs_identity_call_idx ON public.workflow_runs(tenant_id,call_id) WHERE customer_id IS NOT NULL;
CREATE INDEX external_object_references_identity_call_idx ON public.external_object_references(tenant_id,call_id) WHERE customer_id IS NOT NULL;
CREATE INDEX follow_up_tasks_identity_lead_idx ON public.follow_up_tasks(tenant_id,lead_id) WHERE customer_id IS NOT NULL;
CREATE INDEX handoff_requests_identity_lead_idx ON public.handoff_requests(tenant_id,lead_id) WHERE customer_id IS NOT NULL;
CREATE INDEX workflow_runs_identity_lead_idx ON public.workflow_runs(tenant_id,lead_id) WHERE customer_id IS NOT NULL;
CREATE INDEX external_object_references_identity_lead_idx ON public.external_object_references(tenant_id,lead_id) WHERE customer_id IS NOT NULL;
CREATE INDEX handoff_requests_identity_session_idx ON public.handoff_requests(tenant_id,call_session_id) WHERE customer_id IS NOT NULL;
CREATE INDEX consent_records_identity_session_idx ON public.consent_records(tenant_id,call_session_id) WHERE customer_id IS NOT NULL;
