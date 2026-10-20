-- Only reversible while all snapshots are reproducible from the current identity.
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.customer_interactions i JOIN public.customers c ON c.id=i.customer_id AND c.tenant_id=i.tenant_id WHERE
   i.customer_identity_revision<>c.identity_revision OR i.customer_display_name_snapshot IS DISTINCT FROM c.display_name OR
   i.customer_first_name_snapshot IS DISTINCT FROM c.first_name OR i.customer_last_name_snapshot IS DISTINCT FROM c.last_name)
 OR EXISTS(SELECT 1 FROM public.cases x JOIN public.customers c ON c.id=x.customer_id AND c.tenant_id=x.tenant_id WHERE x.customer_identity_revision<>c.identity_revision) THEN
  RAISE EXCEPTION 'Historical identity snapshots differ; use a forward fix';
 END IF;
END $$;
DROP TRIGGER customer_interactions_snapshot_identity ON public.customer_interactions;
DROP TRIGGER cases_snapshot_identity ON public.cases;
DROP FUNCTION public.snapshot_customer_history_identity();
DROP INDEX public.customer_interactions_identity_history_idx;
ALTER TABLE public.customer_interactions DROP COLUMN customer_identity_revision,DROP COLUMN customer_display_name_snapshot,DROP COLUMN customer_first_name_snapshot,DROP COLUMN customer_last_name_snapshot;
ALTER TABLE public.cases DROP COLUMN customer_identity_revision;
