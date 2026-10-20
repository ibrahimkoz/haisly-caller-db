-- Changing history links after insertion would bypass the identity snapshot checks.
CREATE FUNCTION public.guard_customer_history_relationships() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_TABLE_NAME='customer_interactions' THEN
  IF NEW.call_id IS DISTINCT FROM OLD.call_id OR NEW.case_id IS DISTINCT FROM OLD.case_id OR NEW.occurred_at IS DISTINCT FROM OLD.occurred_at THEN
   RAISE EXCEPTION 'Historical relationships require explicit reconciliation' USING ERRCODE='23514';
  END IF;
 ELSE
  IF NEW.source_call_id IS DISTINCT FROM OLD.source_call_id OR NEW.opened_at IS DISTINCT FROM OLD.opened_at THEN
   RAISE EXCEPTION 'Historical relationships require explicit reconciliation' USING ERRCODE='23514';
  END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER customer_interactions_guard_relationships BEFORE UPDATE ON public.customer_interactions FOR EACH ROW EXECUTE FUNCTION public.guard_customer_history_relationships();
CREATE TRIGGER cases_guard_relationships BEFORE UPDATE ON public.cases FOR EACH ROW EXECUTE FUNCTION public.guard_customer_history_relationships();
