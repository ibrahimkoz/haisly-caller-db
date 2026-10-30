SET LOCAL lock_timeout='5s';
CREATE TABLE public.caller_simulation_submission_observations (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 submission_receipt_id bigint NOT NULL,
 observation_key uuid NOT NULL,
 outcome jsonb NOT NULL CHECK(jsonb_typeof(outcome)='object' AND octet_length(outcome::text)<=4096),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(tenant_id,submission_receipt_id,observation_key),
 FOREIGN KEY(submission_receipt_id,tenant_id) REFERENCES public.caller_simulation_submission_receipts(id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_simulation_observation_latest ON public.caller_simulation_submission_observations(tenant_id,submission_receipt_id,id DESC);
CREATE FUNCTION public.guard_simulation_submission_observation() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE item jsonb; seen text[]:='{}'; pending boolean:=false;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Simulation observation is immutable' USING ERRCODE='23514'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.caller_simulation_submission_receipts r WHERE r.id=NEW.submission_receipt_id
  AND r.tenant_id=NEW.tenant_id AND r.invocation_id IS NOT NULL AND r.state IN ('accepted','uncertain')) THEN
  RAISE EXCEPTION 'Simulation observation requires recorded invocation' USING ERRCODE='23514'; END IF;
 IF NEW.outcome->>'state'='unavailable' THEN
  IF NOT COALESCE(NEW.outcome ?& ARRAY['state','reason'] AND NEW.outcome-ARRAY['state','reason']='{}'::jsonb
   AND NEW.outcome->>'reason' IN ('invalid_binding','not_configured','aborted','access_denied','not_found','rate_limited','provider_unavailable','invalid_response','connection_failure','binding_mismatch'),false) THEN
   RAISE EXCEPTION 'Invalid simulation observation failure' USING ERRCODE='23514'; END IF;
 ELSIF NEW.outcome->>'state'='observed' THEN
  IF NOT COALESCE(NEW.outcome ?& ARRAY['state','cancelled','complete','scenarios']
   AND NEW.outcome-ARRAY['state','cancelled','complete','scenarios']='{}'::jsonb
   AND jsonb_typeof(NEW.outcome->'cancelled')='boolean' AND jsonb_typeof(NEW.outcome->'complete')='boolean'
   AND jsonb_typeof(NEW.outcome->'scenarios')='array',false) THEN
   RAISE EXCEPTION 'Invalid simulation observation' USING ERRCODE='23514'; END IF;
  IF jsonb_array_length(NEW.outcome->'scenarios')<>6 THEN RAISE EXCEPTION 'Six observed scenarios required' USING ERRCODE='23514'; END IF;
  FOR item IN SELECT value FROM jsonb_array_elements(NEW.outcome->'scenarios') LOOP
   IF NOT COALESCE(jsonb_typeof(item)='object' AND item ?& ARRAY['scenario','status','condition']
    AND item-ARRAY['scenario','status','condition']='{}'::jsonb
    AND item->>'scenario' IN ('refusal','do_not_call','uncertain_answer','incorrect_information','tool_error','transfer')
    AND item->>'status' IN ('pending','passed','failed','cancelled')
    AND item->>'condition' IN ('success','failure','unknown'),false) OR item->>'scenario'=ANY(seen) THEN
    RAISE EXCEPTION 'Invalid observed simulation scenario' USING ERRCODE='23514'; END IF;
   seen:=array_append(seen,item->>'scenario'); pending:=pending OR item->>'status'='pending';
  END LOOP;
  IF (NEW.outcome->>'complete')::boolean IS DISTINCT FROM (NOT (NEW.outcome->>'cancelled')::boolean AND NOT pending) THEN
   RAISE EXCEPTION 'Inconsistent simulation completion observation' USING ERRCODE='23514'; END IF;
 ELSE RAISE EXCEPTION 'Unknown simulation observation state' USING ERRCODE='23514';
 END IF;
 NEW.created_at:=clock_timestamp(); RETURN NEW;
END $$;
CREATE TRIGGER caller_simulation_observation_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_simulation_submission_observations
 FOR EACH ROW EXECUTE FUNCTION public.guard_simulation_submission_observation();
COMMENT ON TABLE public.caller_simulation_submission_observations IS 'Append-only bounded provider read observations. Does not replace first receipt, finish a job, authorize resend or certify publication.';
