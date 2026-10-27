SET LOCAL lock_timeout = '5s';
ALTER TABLE public.caller_calling_policy_versions
 ADD COLUMN idempotency_key text,
 ADD COLUMN request_hash text,
 ADD CONSTRAINT caller_calling_policy_receipt_pair CHECK (
  (idempotency_key IS NULL AND request_hash IS NULL) OR
  (idempotency_key IS NOT NULL AND length(idempotency_key) BETWEEN 8 AND 200 AND request_hash IS NOT NULL AND request_hash ~ '^[0-9a-f]{64}$'));
CREATE UNIQUE INDEX caller_calling_policy_publication_key ON public.caller_calling_policy_versions(published_by_platform_admin_user_id,idempotency_key) WHERE idempotency_key IS NOT NULL;
