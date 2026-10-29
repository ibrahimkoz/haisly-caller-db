SET LOCAL lock_timeout='5s';
DROP INDEX public.caller_inbound_quota_tenant_unique;
ALTER TABLE public.quota_policies DROP CONSTRAINT caller_inbound_quota_policy_contract;
