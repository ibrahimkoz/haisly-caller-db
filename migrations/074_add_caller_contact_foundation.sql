-- Expand only: legacy customers and all their historical foreign keys remain intact.
-- Promotion to a callable canonical identity is a separate, bounded backfill.
CREATE TABLE public.contact_statuses (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code text NOT NULL UNIQUE CHECK (code IN ('new', 'reachable', 'unreachable', 'declined', 'owner_changed', 'invalid')),
  blocks_calling boolean NOT NULL
);
INSERT INTO public.contact_statuses (code, blocks_calling) VALUES
 ('new', false), ('reachable', false), ('unreachable', false),
 ('declined', false), ('owner_changed', true), ('invalid', true);

ALTER TABLE public.customers
  ALTER COLUMN first_name DROP NOT NULL,
  ALTER COLUMN last_name DROP NOT NULL,
  ADD COLUMN title text CHECK (title IS NULL OR btrim(title) <> ''),
  ADD COLUMN canonical_phone text CHECK (canonical_phone IS NULL OR canonical_phone ~ '^\+[1-9][0-9]{7,14}$'),
  ADD COLUMN contact_state text NOT NULL DEFAULT 'pending_review'
    CHECK (contact_state IN ('pending_review', 'ready', 'conflict')),
  ADD COLUMN country_code text CHECK (country_code IS NULL OR country_code ~ '^[A-Z]{2}$'),
  ADD COLUMN contact_timezone text CHECK (contact_timezone IS NULL OR btrim(contact_timezone) <> ''),
  ADD COLUMN contact_timezone_verified_at timestamptz,
  ADD COLUMN contact_status_id bigint REFERENCES public.contact_statuses(id),
  ADD COLUMN contact_status_occurred_at timestamptz,
  ADD COLUMN identity_revision integer NOT NULL DEFAULT 1 CHECK (identity_revision > 0),
  ADD COLUMN version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  ADD COLUMN archived_at timestamptz,
  ADD COLUMN do_not_call_at timestamptz,
  ADD CONSTRAINT customers_canonical_phone_unique UNIQUE (tenant_id, canonical_phone),
  ADD CONSTRAINT customers_ready_identity_check CHECK (
    contact_state <> 'ready' OR (canonical_phone IS NOT NULL AND canonical_phone = primary_phone AND contact_status_id IS NOT NULL)
  ),
  ADD CONSTRAINT customers_contact_timezone_verified_check CHECK (
    contact_timezone_verified_at IS NULL OR contact_timezone IS NOT NULL
  );
CREATE INDEX customers_caller_page_idx ON public.customers (tenant_id, public_id);

-- Expose conflicts as identifiers/reasons, not a log of raw telephone numbers.
-- Secondary phone claims count too: choosing the primary silently would lose ownership ambiguity.
CREATE VIEW public.caller_contact_backfill_issues AS
WITH claims AS (
  SELECT tenant_id, id AS customer_id, primary_phone AS phone FROM public.customers WHERE primary_phone IS NOT NULL
  UNION
  SELECT tenant_id, customer_id, normalized_value FROM public.customer_contacts WHERE contact_type = 'phone'
), collisions AS (
  SELECT tenant_id, phone FROM claims GROUP BY tenant_id, phone HAVING count(DISTINCT customer_id) > 1
)
SELECT c.tenant_id, c.public_id AS customer_public_id,
  CASE
    WHEN c.primary_phone IS NULL THEN 'missing_primary_phone'
    WHEN EXISTS (SELECT 1 FROM claims x JOIN collisions d USING (tenant_id, phone)
                 WHERE x.customer_id = c.id AND x.tenant_id = c.tenant_id) THEN 'shared_phone'
    WHEN EXISTS (SELECT 1 FROM claims x WHERE x.customer_id = c.id AND x.tenant_id = c.tenant_id
                 AND x.phone <> c.primary_phone) THEN 'multiple_phone_identities'
    ELSE 'unvalidated_phone'
  END AS reason
FROM public.customers c WHERE c.contact_state <> 'ready';

CREATE TABLE public.contact_lists (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name text NOT NULL CHECK (btrim(name) <> '' AND length(name) <= 160),
  version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  archived_at timestamptz,
  first_used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, tenant_id)
);
CREATE UNIQUE INDEX contact_lists_tenant_name_unique ON public.contact_lists (tenant_id, lower(btrim(name)));
CREATE INDEX contact_lists_tenant_page_idx ON public.contact_lists (tenant_id, public_id);
CREATE TABLE public.contact_list_members (
  tenant_id bigint NOT NULL,
  list_id bigint NOT NULL,
  customer_id bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (list_id, customer_id),
  FOREIGN KEY (list_id, tenant_id) REFERENCES public.contact_lists(id, tenant_id) ON DELETE CASCADE,
  FOREIGN KEY (customer_id, tenant_id) REFERENCES public.customers(id, tenant_id) ON DELETE RESTRICT
);
CREATE INDEX contact_list_members_customer_idx ON public.contact_list_members (tenant_id, customer_id, list_id);

CREATE TABLE public.contact_change_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  tenant_id bigint NOT NULL,
  customer_id bigint NOT NULL,
  actor_user_id bigint,
  source text NOT NULL CHECK (source IN ('user', 'runtime', 'import', 'crm', 'backfill')),
  event_type text NOT NULL CHECK (event_type IN ('created', 'updated', 'status_changed', 'identity_changed', 'archived', 'dnc_requested', 'dnc_revoked', 'consent_granted', 'consent_withdrawn')),
  identity_revision integer NOT NULL CHECK (identity_revision > 0),
  reason text NOT NULL CHECK (length(btrim(reason)) BETWEEN 1 AND 1000),
  evidence_reference text CHECK (evidence_reference IS NULL OR length(btrim(evidence_reference)) BETWEEN 1 AND 500),
  before_value jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(before_value) = 'object'),
  after_value jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(after_value) = 'object'),
  occurred_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (customer_id, tenant_id) REFERENCES public.customers(id, tenant_id) ON DELETE RESTRICT,
  FOREIGN KEY (actor_user_id, tenant_id) REFERENCES public.users(id, tenant_id) ON DELETE RESTRICT
);
CREATE INDEX contact_change_events_history_idx ON public.contact_change_events (tenant_id, customer_id, id DESC);

CREATE TABLE public.contact_consents (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  tenant_id bigint NOT NULL,
  customer_id bigint NOT NULL,
  identity_revision integer NOT NULL CHECK (identity_revision > 0),
  purpose text NOT NULL CHECK (purpose IN ('marketing', 'survey')),
  country_code text NOT NULL CHECK (country_code ~ '^[A-Z]{2}$'),
  source text NOT NULL CHECK (length(btrim(source)) BETWEEN 1 AND 100),
  reason text NOT NULL CHECK (length(btrim(reason)) BETWEEN 1 AND 1000),
  evidence_reference text NOT NULL CHECK (length(btrim(evidence_reference)) BETWEEN 1 AND 500),
  granted_at timestamptz NOT NULL,
  withdrawn_at timestamptz,
  actor_user_id bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (customer_id, tenant_id) REFERENCES public.customers(id, tenant_id) ON DELETE RESTRICT,
  FOREIGN KEY (actor_user_id, tenant_id) REFERENCES public.users(id, tenant_id) ON DELETE RESTRICT,
  CHECK (withdrawn_at IS NULL OR withdrawn_at >= granted_at)
);
CREATE INDEX contact_consents_eligibility_idx ON public.contact_consents (tenant_id, customer_id, identity_revision, purpose, country_code) WHERE withdrawn_at IS NULL;

-- Freeze prior identities so ownership correction cannot relabel historical calls.
CREATE TABLE public.contact_identity_revisions (
  tenant_id bigint NOT NULL,
  customer_id bigint NOT NULL,
  revision integer NOT NULL CHECK (revision > 0),
  display_name text NOT NULL,
  valid_from timestamptz NOT NULL,
  valid_until timestamptz NOT NULL,
  reason text NOT NULL CHECK (btrim(reason) <> ''),
  PRIMARY KEY (customer_id, revision),
  FOREIGN KEY (customer_id, tenant_id) REFERENCES public.customers(id, tenant_id) ON DELETE RESTRICT,
  CHECK (valid_until >= valid_from)
);
