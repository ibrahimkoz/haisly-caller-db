CREATE TABLE public.call_provider_snapshots (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  call_id bigint NOT NULL,
  provider text NOT NULL,
  provider_conversation_id text NOT NULL,
  provider_agent_id text,
  provider_agent_name text,
  provider_status text,
  raw_payload jsonb NOT NULL,
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT call_provider_snapshots_public_id_unique UNIQUE (public_id),
  CONSTRAINT call_provider_snapshots_call_provider_unique UNIQUE (call_id, provider),
  CONSTRAINT call_provider_snapshots_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT call_provider_snapshots_call_tenant_fk FOREIGN KEY (call_id, tenant_id)
    REFERENCES public.calls (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT call_provider_snapshots_provider_not_blank_check CHECK (btrim(provider) <> ''),
  CONSTRAINT call_provider_snapshots_provider_conversation_not_blank_check CHECK (btrim(provider_conversation_id) <> ''),
  CONSTRAINT call_provider_snapshots_raw_payload_shape_check CHECK (jsonb_typeof(raw_payload) = 'object')
);

CREATE INDEX call_provider_snapshots_tenant_provider_conversation_idx
  ON public.call_provider_snapshots (tenant_id, provider, provider_conversation_id);

CREATE TABLE public.call_usage_metrics (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  call_id bigint NOT NULL,
  provider text NOT NULL,
  currency text NOT NULL DEFAULT 'USD',
  total_cost numeric(18, 8),
  total_cost_per_minute numeric(18, 8),
  provider_cost_credits integer,
  llm_cost numeric(18, 8),
  platform_cost numeric(18, 8),
  llm_charge_credits integer,
  call_charge_credits integer,
  platform_charge_credits integer,
  llm_input_tokens integer,
  llm_input_cache_read_tokens integer,
  llm_input_cache_write_tokens integer,
  llm_output_tokens integer,
  llm_total_tokens integer,
  tts_model text,
  tts_audio_seconds numeric(18, 6),
  tts_characters integer,
  asr_model text,
  asr_audio_seconds numeric(18, 6),
  asr_transcription_calls integer,
  raw_usage jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT call_usage_metrics_public_id_unique UNIQUE (public_id),
  CONSTRAINT call_usage_metrics_call_provider_unique UNIQUE (call_id, provider),
  CONSTRAINT call_usage_metrics_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT call_usage_metrics_call_tenant_fk FOREIGN KEY (call_id, tenant_id)
    REFERENCES public.calls (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT call_usage_metrics_provider_not_blank_check CHECK (btrim(provider) <> ''),
  CONSTRAINT call_usage_metrics_currency_not_blank_check CHECK (btrim(currency) <> ''),
  CONSTRAINT call_usage_metrics_non_negative_check CHECK (
    (total_cost IS NULL OR total_cost >= 0)
    AND (total_cost_per_minute IS NULL OR total_cost_per_minute >= 0)
    AND (provider_cost_credits IS NULL OR provider_cost_credits >= 0)
    AND (llm_cost IS NULL OR llm_cost >= 0)
    AND (platform_cost IS NULL OR platform_cost >= 0)
    AND (llm_charge_credits IS NULL OR llm_charge_credits >= 0)
    AND (call_charge_credits IS NULL OR call_charge_credits >= 0)
    AND (platform_charge_credits IS NULL OR platform_charge_credits >= 0)
    AND (llm_input_tokens IS NULL OR llm_input_tokens >= 0)
    AND (llm_input_cache_read_tokens IS NULL OR llm_input_cache_read_tokens >= 0)
    AND (llm_input_cache_write_tokens IS NULL OR llm_input_cache_write_tokens >= 0)
    AND (llm_output_tokens IS NULL OR llm_output_tokens >= 0)
    AND (llm_total_tokens IS NULL OR llm_total_tokens >= 0)
    AND (tts_audio_seconds IS NULL OR tts_audio_seconds >= 0)
    AND (tts_characters IS NULL OR tts_characters >= 0)
    AND (asr_audio_seconds IS NULL OR asr_audio_seconds >= 0)
    AND (asr_transcription_calls IS NULL OR asr_transcription_calls >= 0)
  ),
  CONSTRAINT call_usage_metrics_raw_usage_object_check CHECK (jsonb_typeof(raw_usage) = 'object')
);

CREATE INDEX call_usage_metrics_tenant_provider_created_at_idx
  ON public.call_usage_metrics (tenant_id, provider, created_at DESC);
