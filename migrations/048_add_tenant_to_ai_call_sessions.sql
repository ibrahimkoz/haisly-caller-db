ALTER TABLE public.ai_call_sessions
  ADD COLUMN tenant_id bigint;

WITH session_tenants AS (
  SELECT
    session.key,
    min(phone_number.tenant_id) AS tenant_id
  FROM public.ai_call_sessions AS session
  INNER JOIN public.phone_numbers AS phone_number
    ON phone_number.phone_number = session.data ->> 'called_number'
  GROUP BY session.key
  HAVING count(DISTINCT phone_number.tenant_id) = 1
)
UPDATE public.ai_call_sessions AS session
SET tenant_id = session_tenant.tenant_id
FROM session_tenants AS session_tenant
WHERE session_tenant.key = session.key;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.ai_call_sessions
    WHERE tenant_id IS NULL
  ) THEN
    RAISE EXCEPTION
      'Cannot assign tenant_id to every AI call session; resolve missing or ambiguous called_number data first';
  END IF;
END
$$;

ALTER TABLE public.ai_call_sessions
  ALTER COLUMN tenant_id SET NOT NULL,
  ADD CONSTRAINT ai_call_sessions_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE;

CREATE INDEX ai_call_sessions_tenant_updated_at_idx
  ON public.ai_call_sessions (tenant_id, updated_at DESC);
