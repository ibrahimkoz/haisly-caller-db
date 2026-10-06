CREATE TABLE public.ai_call_sessions (
  key text PRIMARY KEY,
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  session_status smallint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ai_call_sessions_key_not_blank_check CHECK (btrim(key) <> ''),
  CONSTRAINT ai_call_sessions_data_object_check CHECK (jsonb_typeof(data) = 'object'),
  CONSTRAINT ai_call_sessions_status_check CHECK (session_status IN (1, 2)),
  CONSTRAINT ai_call_sessions_updated_after_created_check CHECK (updated_at >= created_at)
);
