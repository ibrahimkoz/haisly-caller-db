SET LOCAL lock_timeout = '5s';
CREATE INDEX billing_ledger_correction_idx ON public.billing_ledger_entries(tenant_id,correction_of_entry_id) WHERE kind='adjustment';
CREATE FUNCTION public.guard_billing_adjustment() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE original public.billing_ledger_entries%ROWTYPE; effective numeric;
BEGIN
 PERFORM 1 FROM public.billing_accounts WHERE tenant_id=NEW.tenant_id FOR UPDATE;
 SELECT * INTO original FROM public.billing_ledger_entries WHERE tenant_id=NEW.tenant_id AND id=NEW.correction_of_entry_id;
 IF NOT FOUND OR original.kind NOT IN ('collection','usage') THEN
  RAISE EXCEPTION 'Adjustments must reference an original collection or usage in the same tenant.' USING ERRCODE='23514';
 END IF;
 SELECT original.amount_delta+coalesce(sum(amount_delta),0)+NEW.amount_delta INTO effective
 FROM public.billing_ledger_entries WHERE tenant_id=NEW.tenant_id AND correction_of_entry_id=original.id AND kind='adjustment';
 IF (original.kind='collection' AND effective<0) OR (original.kind='usage' AND effective>0) OR abs(effective)>99999999999999.999999 THEN
  RAISE EXCEPTION 'Correction cannot reverse the original movement sign or exceed the money scale.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER billing_adjustment_guard BEFORE INSERT ON public.billing_ledger_entries
 FOR EACH ROW WHEN (NEW.kind='adjustment') EXECUTE FUNCTION public.guard_billing_adjustment();
