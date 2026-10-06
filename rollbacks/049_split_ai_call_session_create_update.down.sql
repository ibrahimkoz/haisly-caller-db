DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.ai_call_sessions
    GROUP BY key
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION
      'Cannot restore key primary key while duplicate AI call session keys exist';
  END IF;
END
$$;

DROP INDEX IF EXISTS public.ai_call_sessions_key_created_at_idx;

ALTER TABLE public.ai_call_sessions
  DROP CONSTRAINT IF EXISTS ai_call_sessions_pkey,
  DROP CONSTRAINT IF EXISTS ai_call_sessions_public_id_unique,
  DROP COLUMN IF EXISTS public_id,
  DROP COLUMN IF EXISTS id,
  ADD CONSTRAINT ai_call_sessions_pkey PRIMARY KEY (key);
