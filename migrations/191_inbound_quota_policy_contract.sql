SET LOCAL lock_timeout='5s';
ALTER TABLE public.quota_policies ADD CONSTRAINT caller_inbound_quota_policy_contract CHECK (
 quota_code<>'caller.inbound.greeting_admissions' OR (
  enforcement_mode='block' AND hard_limit=trunc(hard_limit) AND hard_limit BETWEEN 1 AND 9007199254740991
  AND ((quota_scope='tenant' AND tenant_environment_id IS NULL) OR (quota_scope='environment' AND tenant_environment_id IS NOT NULL))
 )
);
CREATE UNIQUE INDEX caller_inbound_quota_tenant_unique ON public.quota_policies(tenant_id) WHERE quota_code='caller.inbound.greeting_admissions' AND tenant_environment_id IS NULL AND status<>'archived';
