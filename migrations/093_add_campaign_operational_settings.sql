SET LOCAL lock_timeout = '5s';
ALTER TABLE public.caller_campaign_versions
 ADD COLUMN timezone text NOT NULL DEFAULT 'Europe/Istanbul',
 ADD COLUMN starts_at timestamptz,
 ADD COLUMN ends_at timestamptz,
 ADD COLUMN weekday_mask integer NOT NULL DEFAULT 31 CHECK (weekday_mask BETWEEN 1 AND 127),
 ADD COLUMN window_start_minute integer NOT NULL DEFAULT 600,
 ADD COLUMN window_end_minute integer NOT NULL DEFAULT 1080,
 ADD COLUMN max_attempts integer NOT NULL DEFAULT 3 CHECK (max_attempts BETWEEN 1 AND 5),
 ADD COLUMN requested_concurrency integer NOT NULL DEFAULT 1 CHECK (requested_concurrency BETWEEN 1 AND 20),
 ADD COLUMN max_call_minutes integer NOT NULL DEFAULT 10 CHECK (max_call_minutes BETWEEN 1 AND 15),
 ADD COLUMN agent_config_version_id bigint,
 ADD CONSTRAINT caller_campaign_versions_window CHECK (window_start_minute >= 540 AND window_start_minute < window_end_minute AND window_end_minute <= 1200),
 ADD CONSTRAINT caller_campaign_versions_dates CHECK ((starts_at IS NULL OR isfinite(starts_at)) AND (ends_at IS NULL OR isfinite(ends_at)) AND (starts_at IS NULL OR ends_at IS NULL OR ends_at > starts_at)),
 ADD CONSTRAINT caller_campaign_versions_timezone_length CHECK (length(timezone) BETWEEN 1 AND 100),
 ADD CONSTRAINT caller_campaign_versions_agent_fk FOREIGN KEY (agent_config_version_id, tenant_id) REFERENCES public.agent_config_versions(id, tenant_id) ON DELETE RESTRICT;
UPDATE public.caller_campaign_versions v SET timezone = t.timezone FROM public.tenants t WHERE t.id = v.tenant_id;
CREATE INDEX caller_campaign_versions_agent_idx ON public.caller_campaign_versions(tenant_id,agent_config_version_id) WHERE agent_config_version_id IS NOT NULL;
