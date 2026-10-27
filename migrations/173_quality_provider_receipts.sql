SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_quality_provider_receipts (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 background_job_id bigint NOT NULL,
 prepared_input_id bigint NOT NULL,
 job_attempt_id bigint NOT NULL,
 provider text NOT NULL CHECK(provider='openai'),
 response_id text CHECK(response_id IS NULL OR response_id ~ '^[A-Za-z0-9_-]{1,200}$'),
 request_id text CHECK(request_id IS NULL OR request_id ~ '^[A-Za-z0-9_-]{1,200}$'),
 model text NOT NULL CHECK(model ~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,159}$'),
 outcome text NOT NULL CHECK(outcome IN ('completed','incomplete','refused','invalid','transport_error')),
 http_status integer CHECK(http_status BETWEEN 100 AND 599),
 input_tokens integer CHECK(input_tokens>=0),
 output_tokens integer CHECK(output_tokens>=0),
 total_tokens bigint CHECK(total_tokens>=0),
 cached_input_tokens integer CHECK(cached_input_tokens>=0),
 reasoning_output_tokens integer CHECK(reasoning_output_tokens>=0),
 receipt_hash text NOT NULL CHECK(receipt_hash ~ '^[a-f0-9]{64}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(id,tenant_id), UNIQUE(tenant_id,job_attempt_id),
 FOREIGN KEY(background_job_id,tenant_id) REFERENCES public.background_jobs(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(prepared_input_id,tenant_id) REFERENCES public.caller_quality_evaluation_inputs(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(job_attempt_id,tenant_id) REFERENCES public.job_attempts(id,tenant_id) ON DELETE RESTRICT,
 CHECK(cached_input_tokens IS NULL OR input_tokens IS NULL OR cached_input_tokens<=input_tokens),
 CHECK(reasoning_output_tokens IS NULL OR output_tokens IS NULL OR reasoning_output_tokens<=output_tokens),
 CHECK(total_tokens IS NULL OR input_tokens IS NULL OR output_tokens IS NULL OR total_tokens=input_tokens::bigint+output_tokens::bigint)
);
CREATE UNIQUE INDEX caller_quality_provider_response_unique ON public.caller_quality_provider_receipts(tenant_id,provider,response_id) WHERE response_id IS NOT NULL;
CREATE FUNCTION public.guard_quality_provider_receipt() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Quality provider receipts are immutable' USING ERRCODE='23514'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:'||NEW.tenant_id::text,0));
 PERFORM 1 FROM public.background_jobs j
  JOIN public.job_attempts a ON a.background_job_id=j.id AND a.tenant_id=j.tenant_id
  JOIN public.caller_quality_evaluation_inputs i ON i.background_job_id=j.id AND i.tenant_id=j.tenant_id
  WHERE j.id=NEW.background_job_id AND j.tenant_id=NEW.tenant_id AND j.queue_name='caller-quality' AND j.job_type='quality.evaluate-initial'
   AND a.id=NEW.job_attempt_id AND i.id=NEW.prepared_input_id AND a.attempt_no<=j.active_attempt_no
   AND (a.completed_at IS NULL OR a.completed_at>=i.created_at)
  FOR UPDATE OF j;
 IF NOT FOUND THEN RAISE EXCEPTION 'Quality provider receipt must match prepared job and attempt' USING ERRCODE='23514'; END IF;
 NEW.created_at:=clock_timestamp(); RETURN NEW;
END $$;
CREATE TRIGGER caller_quality_provider_receipt_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_quality_provider_receipts
 FOR EACH ROW EXECUTE FUNCTION public.guard_quality_provider_receipt();
