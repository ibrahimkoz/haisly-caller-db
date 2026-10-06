CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE public.tenants (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  slug text NOT NULL,
  name text NOT NULL,
  status text NOT NULL DEFAULT 'pending_email_verification',
  timezone text NOT NULL DEFAULT 'UTC',
  locale text NOT NULL DEFAULT 'en',
  onboarding_state jsonb NOT NULL DEFAULT '{}'::jsonb,
  activated_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT tenants_public_id_unique UNIQUE (public_id),
  CONSTRAINT tenants_slug_unique UNIQUE (slug),
  CONSTRAINT tenants_slug_format_check CHECK (slug ~ '^[a-z0-9][a-z0-9-]{0,78}[a-z0-9]$'),
  CONSTRAINT tenants_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT tenants_status_check CHECK (status IN (
    'pending_email_verification',
    'active',
    'suspended',
    'cancelled'
  )),
  CONSTRAINT tenants_active_requires_activation_check CHECK (
    status <> 'active' OR activated_at IS NOT NULL
  )
);

CREATE INDEX tenants_status_created_at_idx
  ON public.tenants (status, created_at DESC);

CREATE INDEX tenants_deleted_at_idx
  ON public.tenants (deleted_at)
  WHERE deleted_at IS NOT NULL;

CREATE TABLE public.company_profiles (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  legal_name text,
  display_name text,
  tax_identifier text,
  website_url text,
  industry_code text,
  country_code char(2),
  timezone text,
  locale text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT company_profiles_public_id_unique UNIQUE (public_id),
  CONSTRAINT company_profiles_tenant_id_unique UNIQUE (tenant_id),
  CONSTRAINT company_profiles_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT company_profiles_legal_name_not_blank_check CHECK (
    legal_name IS NULL OR btrim(legal_name) <> ''
  ),
  CONSTRAINT company_profiles_display_name_not_blank_check CHECK (
    display_name IS NULL OR btrim(display_name) <> ''
  ),
  CONSTRAINT company_profiles_country_code_format_check CHECK (
    country_code IS NULL OR country_code ~ '^[A-Z]{2}$'
  )
);

CREATE TABLE public.billing_info (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  billing_email text,
  legal_name text,
  tax_identifier text,
  address_line1 text,
  address_line2 text,
  city text,
  region text,
  postal_code text,
  country_code char(2),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT billing_info_public_id_unique UNIQUE (public_id),
  CONSTRAINT billing_info_tenant_id_unique UNIQUE (tenant_id),
  CONSTRAINT billing_info_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT billing_info_email_format_check CHECK (
    billing_email IS NULL OR billing_email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
  ),
  CONSTRAINT billing_info_country_code_format_check CHECK (
    country_code IS NULL OR country_code ~ '^[A-Z]{2}$'
  )
);

CREATE TABLE public.payment_info (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id bigint NOT NULL,
  provider text,
  provider_customer_ref text,
  payment_method_ref text,
  payment_method_brand text,
  payment_method_last_four char(4),
  payment_method_expiry_month integer,
  payment_method_expiry_year integer,
  status text NOT NULL DEFAULT 'not_configured',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT payment_info_public_id_unique UNIQUE (public_id),
  CONSTRAINT payment_info_tenant_id_unique UNIQUE (tenant_id),
  CONSTRAINT payment_info_tenant_id_fk FOREIGN KEY (tenant_id)
    REFERENCES public.tenants (id)
    ON DELETE CASCADE,
  CONSTRAINT payment_info_status_check CHECK (status IN (
    'not_configured',
    'pending',
    'active',
    'failed',
    'disabled'
  )),
  CONSTRAINT payment_info_last_four_format_check CHECK (
    payment_method_last_four IS NULL OR payment_method_last_four ~ '^[0-9]{4}$'
  ),
  CONSTRAINT payment_info_expiry_month_check CHECK (
    payment_method_expiry_month IS NULL
    OR payment_method_expiry_month BETWEEN 1 AND 12
  ),
  CONSTRAINT payment_info_expiry_year_check CHECK (
    payment_method_expiry_year IS NULL
    OR payment_method_expiry_year BETWEEN 2000 AND 2200
  ),
  CONSTRAINT payment_info_provider_not_blank_check CHECK (
    provider IS NULL OR btrim(provider) <> ''
  ),
  CONSTRAINT payment_info_provider_customer_ref_not_blank_check CHECK (
    provider_customer_ref IS NULL OR btrim(provider_customer_ref) <> ''
  ),
  CONSTRAINT payment_info_payment_method_ref_not_blank_check CHECK (
    payment_method_ref IS NULL OR btrim(payment_method_ref) <> ''
  )
);
