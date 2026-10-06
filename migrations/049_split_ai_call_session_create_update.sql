ALTER TABLE public.ai_call_sessions
  ADD COLUMN id bigint GENERATED ALWAYS AS IDENTITY,
  ADD COLUMN public_id uuid NOT NULL DEFAULT gen_random_uuid();

ALTER TABLE public.ai_call_sessions
  DROP CONSTRAINT ai_call_sessions_pkey,
  ADD CONSTRAINT ai_call_sessions_pkey PRIMARY KEY (id),
  ADD CONSTRAINT ai_call_sessions_public_id_unique UNIQUE (public_id);

CREATE INDEX ai_call_sessions_key_created_at_idx
  ON public.ai_call_sessions (key, created_at DESC);
