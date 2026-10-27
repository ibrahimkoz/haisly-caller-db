SET LOCAL lock_timeout = '5s';
LOCK TABLE public.caller_calling_policy_versions IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_calling_policy_versions WHERE idempotency_key IS NOT NULL) THEN RAISE EXCEPTION 'Policy publication receipts exist; use a forward fix.'; END IF;
END $$;
DROP INDEX public.caller_calling_policy_publication_key;
ALTER TABLE public.caller_calling_policy_versions DROP CONSTRAINT caller_calling_policy_receipt_pair, DROP COLUMN idempotency_key, DROP COLUMN request_hash;
