ALTER TABLE public.ai_call_sessions
  ADD COLUMN IF NOT EXISTS key text NOT NULL DEFAULT gen_random_uuid()::text,
  ADD CONSTRAINT ai_call_sessions_key_not_blank_check CHECK (btrim(key) <> '');

CREATE INDEX IF NOT EXISTS ai_call_sessions_key_created_at_idx
  ON public.ai_call_sessions (key, created_at DESC);
