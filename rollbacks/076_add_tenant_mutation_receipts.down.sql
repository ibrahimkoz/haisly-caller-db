DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM public.tenant_mutation_receipts) THEN
  RAISE EXCEPTION 'Mutation receipts exist; keep replay protection and use a forward fix';
 END IF;
END $$;
DROP TABLE public.tenant_mutation_receipts;
