SET LOCAL lock_timeout = '5s';
CREATE INDEX caller_dispatch_phone_end_history ON public.caller_dispatch_intents(tenant_id,canonical_phone,ended_at DESC,id DESC) WHERE ended_at IS NOT NULL;
CREATE INDEX caller_dispatch_campaign_end_history ON public.caller_dispatch_intents(tenant_id,canonical_phone,campaign_id,ended_at DESC,id DESC) WHERE ended_at IS NOT NULL;
