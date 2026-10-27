SET LOCAL lock_timeout = '5s';
-- Local/additive migration. For a large production dispatch table, build the
-- equivalent index CONCURRENTLY outside a transaction before registering this version.
CREATE INDEX caller_dispatch_campaign_operations_idx ON public.caller_dispatch_intents(tenant_id,campaign_id,state) INCLUDE(reservation_id);
