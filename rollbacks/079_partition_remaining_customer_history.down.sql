DO $$ DECLARE relation text; changed boolean; BEGIN
 FOREACH relation IN ARRAY ARRAY['leads','follow_up_tasks','handoff_requests','workflow_runs','external_object_references','consent_records'] LOOP
  EXECUTE format('SELECT EXISTS(SELECT 1 FROM public.%I h JOIN public.customers c ON c.id=h.customer_id AND c.tenant_id=h.tenant_id WHERE h.customer_identity_revision<>c.identity_revision)',relation) INTO changed;
  IF changed THEN RAISE EXCEPTION 'Historical revisions differ; use a forward fix'; END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM public.handoff_requests h JOIN public.customers c ON c.id=h.customer_id AND c.tenant_id=h.tenant_id WHERE h.customer_display_name_snapshot IS DISTINCT FROM c.display_name OR h.customer_first_name_snapshot IS DISTINCT FROM c.first_name OR h.customer_last_name_snapshot IS DISTINCT FROM c.last_name) THEN
  RAISE EXCEPTION 'Historical handoff names differ; use a forward fix';
 END IF;
 FOREACH relation IN ARRAY ARRAY['leads','follow_up_tasks','handoff_requests','workflow_runs','external_object_references','consent_records'] LOOP
  EXECUTE format('DROP TRIGGER %I ON public.%I',relation||'_snapshot_identity',relation);
  EXECUTE format('ALTER TABLE public.%I DROP COLUMN customer_identity_revision',relation);
 END LOOP;
END $$;
ALTER TABLE public.handoff_requests DROP COLUMN customer_display_name_snapshot,DROP COLUMN customer_first_name_snapshot,DROP COLUMN customer_last_name_snapshot;
DROP FUNCTION public.snapshot_remaining_customer_history();
DROP TRIGGER cases_validate_related_identity ON public.cases;
DROP TRIGGER customer_interactions_validate_related_identity ON public.customer_interactions;
DROP FUNCTION public.enforce_related_customer_identity();
DROP FUNCTION public.guard_related_customer_identity(bigint,bigint,integer,jsonb);
