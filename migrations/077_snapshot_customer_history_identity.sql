-- Expand history without replacing customer IDs or deleting historical records.
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';
ALTER TABLE public.customer_interactions
 ADD COLUMN customer_identity_revision integer,
 ADD COLUMN customer_display_name_snapshot text,
 ADD COLUMN customer_first_name_snapshot text,
 ADD COLUMN customer_last_name_snapshot text;
ALTER TABLE public.cases ADD COLUMN customer_identity_revision integer;
UPDATE public.customer_interactions i SET
 customer_identity_revision=c.identity_revision,
 customer_display_name_snapshot=c.display_name,
 customer_first_name_snapshot=c.first_name,
 customer_last_name_snapshot=c.last_name
FROM public.customers c WHERE c.id=i.customer_id AND c.tenant_id=i.tenant_id;
UPDATE public.cases x SET customer_identity_revision=c.identity_revision
FROM public.customers c WHERE c.id=x.customer_id AND c.tenant_id=x.tenant_id;
ALTER TABLE public.customer_interactions
 ALTER COLUMN customer_identity_revision SET NOT NULL,
 ALTER COLUMN customer_display_name_snapshot SET NOT NULL,
 ADD CONSTRAINT customer_interactions_revision_check CHECK(customer_identity_revision>0);
ALTER TABLE public.cases ADD CONSTRAINT cases_customer_revision_check CHECK(
 (customer_id IS NULL AND customer_identity_revision IS NULL) OR
 (customer_id IS NOT NULL AND customer_identity_revision IS NOT NULL AND customer_identity_revision>0));
CREATE INDEX customer_interactions_identity_history_idx ON public.customer_interactions(tenant_id,customer_id,customer_identity_revision,occurred_at DESC);

CREATE FUNCTION public.snapshot_customer_history_identity() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE person public.customers%ROWTYPE; identity_boundary timestamptz;
BEGIN
 IF TG_OP='UPDATE' THEN
  IF NEW.customer_id IS DISTINCT FROM OLD.customer_id OR NEW.tenant_id IS DISTINCT FROM OLD.tenant_id
     OR NEW.customer_identity_revision IS DISTINCT FROM OLD.customer_identity_revision THEN
   RAISE EXCEPTION 'Historical customer identity cannot be reassigned' USING ERRCODE='23514';
  END IF;
  IF TG_TABLE_NAME='customer_interactions' THEN
   IF NEW.customer_display_name_snapshot IS DISTINCT FROM OLD.customer_display_name_snapshot
      OR NEW.customer_first_name_snapshot IS DISTINCT FROM OLD.customer_first_name_snapshot
      OR NEW.customer_last_name_snapshot IS DISTINCT FROM OLD.customer_last_name_snapshot THEN
    RAISE EXCEPTION 'Historical customer snapshot is immutable' USING ERRCODE='23514';
   END IF;
  END IF;
  RETURN NEW;
 END IF;
 IF NEW.customer_id IS NULL THEN
  NEW.customer_identity_revision:=NULL;
  RETURN NEW;
 END IF;
 -- Serialize the snapshot with changes to this person's identity.
 SELECT * INTO person FROM public.customers WHERE id=NEW.customer_id AND tenant_id=NEW.tenant_id FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Customer is outside tenant scope' USING ERRCODE='23503'; END IF;
 IF NEW.customer_identity_revision IS NOT NULL AND NEW.customer_identity_revision<>person.identity_revision THEN
  RAISE EXCEPTION 'Historical identity requires explicit reconciliation' USING ERRCODE='23514';
 END IF;
 SELECT max(valid_until) INTO identity_boundary FROM public.contact_identity_revisions WHERE tenant_id=NEW.tenant_id AND customer_id=NEW.customer_id;
 IF identity_boundary IS NOT NULL THEN
  IF TG_TABLE_NAME='customer_interactions' THEN
   IF NEW.occurred_at<identity_boundary THEN RAISE EXCEPTION 'Late history requires identity reconciliation' USING ERRCODE='23514'; END IF;
  ELSE
   IF NEW.opened_at<identity_boundary THEN RAISE EXCEPTION 'Late history requires identity reconciliation' USING ERRCODE='23514'; END IF;
  END IF;
 END IF;
 NEW.customer_identity_revision:=person.identity_revision;
 IF TG_TABLE_NAME='customer_interactions' THEN
  NEW.customer_display_name_snapshot:=person.display_name;
  NEW.customer_first_name_snapshot:=person.first_name;
  NEW.customer_last_name_snapshot:=person.last_name;
  -- A call or case cannot join two people/revisions through a later interaction.
  IF NEW.call_id IS NOT NULL THEN
   PERFORM 1 FROM public.calls WHERE id=NEW.call_id AND tenant_id=NEW.tenant_id FOR UPDATE;
   IF EXISTS(SELECT 1 FROM public.customer_interactions i WHERE i.tenant_id=NEW.tenant_id AND i.call_id=NEW.call_id AND
      (i.customer_id<>NEW.customer_id OR i.customer_identity_revision<>NEW.customer_identity_revision)) THEN
    RAISE EXCEPTION 'Call belongs to another customer identity' USING ERRCODE='23514';
   END IF;
  END IF;
  IF NEW.case_id IS NOT NULL AND EXISTS(SELECT 1 FROM public.cases x WHERE x.id=NEW.case_id AND x.tenant_id=NEW.tenant_id AND x.customer_id IS NOT NULL AND
      (x.customer_id<>NEW.customer_id OR x.customer_identity_revision<>NEW.customer_identity_revision)) THEN
   RAISE EXCEPTION 'Case belongs to another customer identity' USING ERRCODE='23514';
  END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER customer_interactions_snapshot_identity BEFORE INSERT OR UPDATE ON public.customer_interactions FOR EACH ROW EXECUTE FUNCTION public.snapshot_customer_history_identity();
CREATE TRIGGER cases_snapshot_identity BEFORE INSERT OR UPDATE ON public.cases FOR EACH ROW EXECUTE FUNCTION public.snapshot_customer_history_identity();
