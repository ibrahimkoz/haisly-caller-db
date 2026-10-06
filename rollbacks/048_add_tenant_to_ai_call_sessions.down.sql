DROP INDEX IF EXISTS public.ai_call_sessions_tenant_updated_at_idx;

ALTER TABLE public.ai_call_sessions
  DROP CONSTRAINT IF EXISTS ai_call_sessions_tenant_id_fk,
  DROP COLUMN IF EXISTS tenant_id;
