CREATE TABLE public.calls (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  ai_agent_id bigint,
  phone_number_id bigint,
  provider_call_id text NOT NULL,
  direction text NOT NULL DEFAULT 'inbound',
  status text NOT NULL DEFAULT 'ringing',
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  duration_seconds integer,
  recording_available boolean NOT NULL DEFAULT false,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT calls_public_id_unique UNIQUE (public_id),
  CONSTRAINT calls_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT calls_tenant_provider_call_unique UNIQUE (tenant_id, provider_call_id),
  CONSTRAINT calls_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT calls_ai_agent_tenant_fk FOREIGN KEY (ai_agent_id, tenant_id)
    REFERENCES public.ai_agents (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT calls_phone_number_tenant_fk FOREIGN KEY (phone_number_id, tenant_id)
    REFERENCES public.phone_numbers (id, tenant_id)
    ON DELETE SET NULL,
  CONSTRAINT calls_provider_call_id_not_blank_check CHECK (btrim(provider_call_id) <> ''),
  CONSTRAINT calls_direction_check CHECK (direction IN (
    'inbound',
    'outbound',
    'internal'
  )),
  CONSTRAINT calls_status_check CHECK (status IN (
    'ringing',
    'in_progress',
    'completed',
    'failed',
    'no_answer',
    'busy',
    'canceled'
  )),
  CONSTRAINT calls_duration_non_negative_check CHECK (
    duration_seconds IS NULL OR duration_seconds >= 0
  ),
  CONSTRAINT calls_ended_after_started_check CHECK (
    ended_at IS NULL OR ended_at >= started_at
  ),
  CONSTRAINT calls_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX calls_tenant_status_started_at_idx
  ON public.calls (tenant_id, status, started_at DESC);

CREATE INDEX calls_tenant_ai_agent_started_at_idx
  ON public.calls (tenant_id, ai_agent_id, started_at DESC)
  WHERE ai_agent_id IS NOT NULL;

CREATE INDEX calls_tenant_phone_number_started_at_idx
  ON public.calls (tenant_id, phone_number_id, started_at DESC)
  WHERE phone_number_id IS NOT NULL;

CREATE TABLE public.call_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  call_id bigint NOT NULL,
  event_type text NOT NULL,
  source text,
  event_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT call_events_public_id_unique UNIQUE (public_id),
  CONSTRAINT call_events_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT call_events_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT call_events_call_tenant_fk FOREIGN KEY (call_id, tenant_id)
    REFERENCES public.calls (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT call_events_event_type_not_blank_check CHECK (btrim(event_type) <> ''),
  CONSTRAINT call_events_source_not_blank_check CHECK (
    source IS NULL OR btrim(source) <> ''
  ),
  CONSTRAINT call_events_event_payload_object_check CHECK (
    jsonb_typeof(event_payload) = 'object'
  )
);

CREATE INDEX call_events_call_occurred_at_idx
  ON public.call_events (call_id, occurred_at ASC);

CREATE INDEX call_events_tenant_event_type_occurred_at_idx
  ON public.call_events (tenant_id, event_type, occurred_at DESC);

CREATE TABLE public.call_transcripts (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  call_id bigint NOT NULL,
  segment_index integer NOT NULL,
  speaker_type text NOT NULL,
  content text NOT NULL,
  language text,
  started_at timestamptz,
  ended_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT call_transcripts_public_id_unique UNIQUE (public_id),
  CONSTRAINT call_transcripts_call_segment_unique UNIQUE (call_id, segment_index),
  CONSTRAINT call_transcripts_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT call_transcripts_call_tenant_fk FOREIGN KEY (call_id, tenant_id)
    REFERENCES public.calls (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT call_transcripts_segment_positive_check CHECK (segment_index > 0),
  CONSTRAINT call_transcripts_speaker_type_check CHECK (speaker_type IN (
    'agent',
    'customer',
    'system',
    'unknown'
  )),
  CONSTRAINT call_transcripts_content_not_blank_check CHECK (btrim(content) <> ''),
  CONSTRAINT call_transcripts_language_not_blank_check CHECK (
    language IS NULL OR btrim(language) <> ''
  ),
  CONSTRAINT call_transcripts_ended_after_started_check CHECK (
    ended_at IS NULL OR started_at IS NULL OR ended_at >= started_at
  ),
  CONSTRAINT call_transcripts_metadata_object_check CHECK (
    jsonb_typeof(metadata) = 'object'
  )
);

CREATE INDEX call_transcripts_call_segment_idx
  ON public.call_transcripts (call_id, segment_index ASC);

CREATE TABLE public.call_recordings (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  call_id bigint NOT NULL,
  provider_recording_id text,
  storage_ref text,
  status text NOT NULL DEFAULT 'pending',
  duration_seconds integer,
  started_at timestamptz,
  ended_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT call_recordings_public_id_unique UNIQUE (public_id),
  CONSTRAINT call_recordings_id_tenant_id_unique UNIQUE (id, tenant_id),
  CONSTRAINT call_recordings_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT call_recordings_call_tenant_fk FOREIGN KEY (call_id, tenant_id)
    REFERENCES public.calls (id, tenant_id)
    ON DELETE CASCADE,
  CONSTRAINT call_recordings_provider_recording_not_blank_check CHECK (
    provider_recording_id IS NULL OR btrim(provider_recording_id) <> ''
  ),
  CONSTRAINT call_recordings_storage_ref_not_blank_check CHECK (
    storage_ref IS NULL OR btrim(storage_ref) <> ''
  ),
  CONSTRAINT call_recordings_status_check CHECK (status IN (
    'pending',
    'available',
    'processing',
    'failed',
    'redacted',
    'deleted'
  )),
  CONSTRAINT call_recordings_duration_non_negative_check CHECK (
    duration_seconds IS NULL OR duration_seconds >= 0
  ),
  CONSTRAINT call_recordings_ended_after_started_check CHECK (
    ended_at IS NULL OR started_at IS NULL OR ended_at >= started_at
  ),
  CONSTRAINT call_recordings_metadata_object_check CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE UNIQUE INDEX call_recordings_tenant_provider_recording_unique_idx
  ON public.call_recordings (tenant_id, provider_recording_id)
  WHERE provider_recording_id IS NOT NULL;

CREATE INDEX call_recordings_call_status_created_at_idx
  ON public.call_recordings (call_id, status, created_at DESC);
