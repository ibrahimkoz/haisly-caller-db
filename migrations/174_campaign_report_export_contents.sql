SET LOCAL lock_timeout='5s';
ALTER TABLE public.export_jobs ADD CONSTRAINT export_jobs_id_tenant_unique UNIQUE(id,tenant_id);
CREATE TABLE public.caller_report_export_contents (
 artifact_id bigint PRIMARY KEY,
 tenant_id bigint NOT NULL,
 export_job_id bigint NOT NULL,
 background_job_id bigint NOT NULL,
 job_attempt_id bigint NOT NULL,
 csv_content text NOT NULL CHECK(octet_length(csv_content) BETWEEN 1 AND 10485760),
 expires_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(tenant_id,export_job_id),
 FOREIGN KEY(artifact_id,tenant_id) REFERENCES public.artifacts(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(export_job_id,tenant_id) REFERENCES public.export_jobs(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(background_job_id,tenant_id) REFERENCES public.background_jobs(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(job_attempt_id,tenant_id) REFERENCES public.job_attempts(id,tenant_id) ON DELETE RESTRICT,
 CHECK(expires_at>created_at)
);
CREATE INDEX caller_report_export_expiry_idx ON public.caller_report_export_contents(expires_at,artifact_id);
CREATE FUNCTION public.guard_report_export_content() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE j public.background_jobs%ROWTYPE; e public.export_jobs%ROWTYPE; a public.artifacts%ROWTYPE;
BEGIN
 IF TG_OP='DELETE' THEN
  IF OLD.expires_at>clock_timestamp() THEN RAISE EXCEPTION 'Unexpired report export content cannot be deleted' USING ERRCODE='23514'; END IF;
  RETURN OLD;
 END IF;
 IF TG_OP='UPDATE' THEN RAISE EXCEPTION 'Report export content is immutable' USING ERRCODE='23514'; END IF;
 SELECT * INTO j FROM public.background_jobs WHERE id=NEW.background_job_id AND tenant_id=NEW.tenant_id FOR UPDATE;
 IF NOT FOUND OR j.queue_name<>'caller-report-export' OR j.job_type<>'caller.aggregate-report.v1' OR j.status<>'running'
  OR j.lease_expires_at IS NULL OR j.lease_expires_at<=clock_timestamp() THEN
  RAISE EXCEPTION 'Report export requires active dedicated lease' USING ERRCODE='23514'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.job_attempts WHERE id=NEW.job_attempt_id AND tenant_id=NEW.tenant_id
  AND background_job_id=j.id AND attempt_no=j.active_attempt_no AND status='running') THEN
  RAISE EXCEPTION 'Report export attempt does not match lease' USING ERRCODE='23514'; END IF;
 SELECT * INTO e FROM public.export_jobs WHERE id=NEW.export_job_id AND tenant_id=NEW.tenant_id FOR UPDATE;
 IF NOT FOUND OR e.job_type<>'caller.aggregate-report.v1' OR e.output_format<>'csv' OR e.status NOT IN ('queued','processing')
  OR e.requested_by_user_id IS NULL OR e.requested_by_user_id IS DISTINCT FROM j.created_by_user_id
  OR j.payload IS DISTINCT FROM jsonb_build_object('schema_version',1,'export_job_public_id',e.public_id)
  OR NEW.expires_at IS DISTINCT FROM (e.metadata->>'expires_at')::timestamptz THEN
  RAISE EXCEPTION 'Report export request mismatch' USING ERRCODE='23514'; END IF;
 SELECT * INTO a FROM public.artifacts WHERE id=NEW.artifact_id AND tenant_id=NEW.tenant_id;
 IF NOT FOUND OR a.owner_entity_type<>'export_job' OR a.owner_entity_id<>e.id
  OR a.artifact_type<>'campaign_aggregate_csv' OR a.storage_provider IS DISTINCT FROM 'postgres'
  OR a.storage_ref IS DISTINCT FROM 'report-export:'||e.public_id::text
  OR a.status<>'available' OR a.privacy_classification<>'restricted'
  OR a.byte_size<>octet_length(NEW.csv_content)
  OR a.checksum_sha256 IS DISTINCT FROM encode(digest(NEW.csv_content,'sha256'),'hex') THEN
  RAISE EXCEPTION 'Report export artifact mismatch' USING ERRCODE='23514'; END IF;
 NEW.created_at:=clock_timestamp();
 IF NEW.expires_at<=NEW.created_at THEN RAISE EXCEPTION 'Report export expired' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_report_export_content_guard BEFORE INSERT OR UPDATE OR DELETE ON public.caller_report_export_contents
 FOR EACH ROW EXECUTE FUNCTION public.guard_report_export_content();
