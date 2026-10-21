-- Draft authoring only. Publication/target snapshots require later guarded migrations.
SET LOCAL lock_timeout = '5s';
CREATE TABLE public.caller_campaigns (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
 name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 160),
 campaign_type text NOT NULL CHECK (campaign_type IN ('marketing','survey')),
 state text NOT NULL DEFAULT 'draft' CHECK (state = 'draft'),
 version integer NOT NULL DEFAULT 1 CHECK (version > 0),
 created_by_user_id bigint NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (id, tenant_id),
 FOREIGN KEY (created_by_user_id, tenant_id) REFERENCES public.users(id, tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_campaigns_tenant_public_idx ON public.caller_campaigns(tenant_id, public_id);
CREATE TABLE public.caller_campaign_versions (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 campaign_id bigint NOT NULL,
 revision integer NOT NULL DEFAULT 1 CHECK (revision > 0),
 state text NOT NULL DEFAULT 'draft' CHECK (state = 'draft'),
 behavior_instructions text NOT NULL DEFAULT '' CHECK (length(behavior_instructions) <= 20000),
 topic_instructions text NOT NULL DEFAULT '' CHECK (length(topic_instructions) <= 50000),
 objective text NOT NULL DEFAULT '' CHECK (length(objective) <= 2000),
 language text NOT NULL DEFAULT 'tr' CHECK (language IN ('tr','en')),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (id, tenant_id),
 UNIQUE (campaign_id, revision),
 FOREIGN KEY (campaign_id, tenant_id) REFERENCES public.caller_campaigns(id, tenant_id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX caller_campaign_versions_one_draft_idx ON public.caller_campaign_versions(campaign_id) WHERE state = 'draft';
CREATE TABLE public.caller_campaign_source_lists (
 tenant_id bigint NOT NULL,
 campaign_version_id bigint NOT NULL,
 list_id bigint NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY (campaign_version_id, list_id),
 FOREIGN KEY (campaign_version_id, tenant_id) REFERENCES public.caller_campaign_versions(id, tenant_id) ON DELETE CASCADE,
 FOREIGN KEY (list_id, tenant_id) REFERENCES public.contact_lists(id, tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_campaign_source_lists_list_idx ON public.caller_campaign_source_lists(tenant_id, list_id);
