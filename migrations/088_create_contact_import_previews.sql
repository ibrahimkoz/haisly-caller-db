-- Preview only: importing contacts requires a later explicit confirmation/worker contract.
SET LOCAL lock_timeout = '5s';
CREATE TABLE public.contact_import_previews (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
 list_id bigint NOT NULL,
 actor_user_id bigint NOT NULL,
 storage_id uuid NOT NULL UNIQUE,
 file_sha256 text NOT NULL CHECK (file_sha256 ~ '^[0-9a-f]{64}$'),
 file_size integer NOT NULL CHECK (file_size BETWEEN 1 AND 10485760),
 format text NOT NULL CHECK (format IN ('csv','xls','xlsx')),
 mapping jsonb NOT NULL CHECK (jsonb_typeof(mapping) = 'object'),
 summary jsonb NOT NULL CHECK (jsonb_typeof(summary) = 'object'),
 created_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz NOT NULL CHECK (expires_at > created_at),
 UNIQUE (id, tenant_id),
 FOREIGN KEY (list_id, tenant_id) REFERENCES public.contact_lists(id, tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY (actor_user_id, tenant_id) REFERENCES public.users(id, tenant_id) ON DELETE RESTRICT
);
CREATE INDEX contact_import_previews_tenant_created_idx ON public.contact_import_previews (tenant_id, created_at DESC);
CREATE INDEX contact_import_previews_expiry_idx ON public.contact_import_previews (expires_at);
CREATE TABLE public.contact_import_preview_rows (
 preview_id bigint NOT NULL,
 tenant_id bigint NOT NULL,
 row_number integer NOT NULL CHECK (row_number BETWEEN 2 AND 50001),
 status text NOT NULL CHECK (status IN ('valid','invalid','duplicate')),
 duplicate_of integer,
 phone text CHECK (phone IS NULL OR phone ~ '^\+[1-9][0-9]{7,14}$'),
 country_code text CHECK (country_code IS NULL OR country_code ~ '^[A-Z]{2}$'),
 first_name text CHECK (length(first_name) <= 160),
 last_name text CHECK (length(last_name) <= 160),
 title text CHECK (length(title) <= 160),
 issues jsonb NOT NULL CHECK (jsonb_typeof(issues) = 'array'),
 PRIMARY KEY (preview_id, row_number),
 FOREIGN KEY (preview_id, tenant_id) REFERENCES public.contact_import_previews(id, tenant_id) ON DELETE CASCADE,
 CHECK ((status = 'duplicate') = (duplicate_of IS NOT NULL)),
 CHECK (duplicate_of IS NULL OR duplicate_of < row_number),
 CHECK (status = 'invalid' OR (phone IS NOT NULL AND country_code IS NOT NULL AND issues = '[]'::jsonb))
);
