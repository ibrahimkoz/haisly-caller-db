DROP INDEX IF EXISTS public.ai_call_sessions_key_created_at_idx;

ALTER TABLE public.ai_call_sessions
  DROP CONSTRAINT IF EXISTS ai_call_sessions_key_not_blank_check,
  DROP COLUMN IF EXISTS key;
