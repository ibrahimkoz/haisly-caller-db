CREATE TABLE IF NOT EXISTS public.finalize_logs (
  id bigserial PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  request_payload jsonb NOT NULL,
  message text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT finalize_logs_public_id_unique UNIQUE (public_id)
);
