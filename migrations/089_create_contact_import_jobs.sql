SET LOCAL lock_timeout = '5s';
ALTER TABLE background_jobs ADD CONSTRAINT background_jobs_id_tenant_key UNIQUE (id, tenant_id);
CREATE TABLE contact_import_jobs (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL REFERENCES tenants(id),
 preview_id bigint NOT NULL UNIQUE,
 actor_user_id bigint NOT NULL,
 background_job_id bigint NOT NULL UNIQUE,
 state text NOT NULL DEFAULT 'queued' CHECK(state IN ('queued','running','completed','cancelled')),
 version integer NOT NULL DEFAULT 1 CHECK(version > 0),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(id, tenant_id),
 FOREIGN KEY(preview_id, tenant_id) REFERENCES contact_import_previews(id, tenant_id),
 FOREIGN KEY(actor_user_id, tenant_id) REFERENCES users(id, tenant_id),
 FOREIGN KEY(background_job_id, tenant_id) REFERENCES background_jobs(id, tenant_id)
);
CREATE INDEX contact_import_jobs_tenant_created_idx ON contact_import_jobs(tenant_id, created_at DESC);
CREATE TABLE contact_import_job_rows (
 job_id bigint NOT NULL,
 tenant_id bigint NOT NULL,
 row_number integer NOT NULL CHECK(row_number BETWEEN 2 AND 50001),
 expected_contact_public_id uuid,
 expected_version integer,
 expected_identity_revision integer,
 overwrite_fields text[] NOT NULL DEFAULT '{}',
 state text NOT NULL DEFAULT 'pending' CHECK(state IN ('pending','applied','conflict')),
 result_code text,
 PRIMARY KEY(job_id,row_number),
 FOREIGN KEY(job_id,tenant_id) REFERENCES contact_import_jobs(id,tenant_id) ON DELETE CASCADE,
 CHECK ((expected_contact_public_id IS NULL AND expected_version IS NULL AND expected_identity_revision IS NULL)
 OR (expected_contact_public_id IS NOT NULL AND expected_version > 0 AND expected_identity_revision > 0)),
 CHECK(overwrite_fields <@ ARRAY['first_name','last_name','title']::text[]),
 CHECK((state='pending' AND result_code IS NULL) OR (state<>'pending' AND result_code IS NOT NULL))
);
CREATE INDEX contact_import_job_rows_pending_idx ON contact_import_job_rows(job_id,row_number) WHERE state='pending';
