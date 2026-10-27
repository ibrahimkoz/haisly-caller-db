SET LOCAL lock_timeout = '5s';
LOCK TABLE public.billing_tariff_versions IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.billing_tariff_versions WHERE idempotency_key IS NOT NULL LIMIT 1) THEN
 RAISE EXCEPTION 'Publication receipts exist; use a forward fix.';
 END IF;
END $$;
DROP INDEX public.tariff_publication_receipt_key;
ALTER TABLE public.billing_tariff_versions DROP CONSTRAINT tariff_publication_receipt_pair, DROP COLUMN idempotency_key, DROP COLUMN request_hash;
