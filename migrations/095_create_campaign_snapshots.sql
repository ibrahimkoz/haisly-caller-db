SET LOCAL lock_timeout = '5s';
-- Immutable authoring checkpoints; not published campaigns or recipient snapshots.
CREATE TABLE public.caller_campaign_snapshots (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 public_id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
 tenant_id bigint NOT NULL,
 campaign_id bigint NOT NULL,
 snapshot_no integer NOT NULL CHECK (snapshot_no > 0),
 source_version integer NOT NULL CHECK (source_version > 0),
 schema_version integer NOT NULL DEFAULT 1 CHECK (schema_version = 1),
 snapshot_hash text NOT NULL CHECK (snapshot_hash ~ '^[a-f0-9]{64}$'),
 definition_hash text NOT NULL CHECK (definition_hash ~ '^[a-f0-9]{64}$'),
 document jsonb NOT NULL CHECK (jsonb_typeof(document)='object' AND octet_length(document::text)<=8388608),
 agent_snapshot jsonb CHECK (agent_snapshot IS NULL OR (jsonb_typeof(agent_snapshot)='object' AND octet_length(agent_snapshot::text)<=8388608)),
 created_by_user_id bigint NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(id,tenant_id),
 UNIQUE(campaign_id,snapshot_no),
 UNIQUE(campaign_id,snapshot_hash),
 FOREIGN KEY(campaign_id,tenant_id) REFERENCES public.caller_campaigns(id,tenant_id) ON DELETE RESTRICT,
 FOREIGN KEY(created_by_user_id,tenant_id) REFERENCES public.users(id,tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_campaign_snapshots_tenant_campaign_idx ON public.caller_campaign_snapshots(tenant_id,campaign_id,snapshot_no DESC);
CREATE FUNCTION public.reject_caller_campaign_snapshot_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 RAISE EXCEPTION 'Campaign snapshots are immutable; create another snapshot.' USING ERRCODE='23514';
END;
$$;
CREATE TRIGGER caller_campaign_snapshots_immutable BEFORE UPDATE OR DELETE ON public.caller_campaign_snapshots
 FOR EACH ROW EXECUTE FUNCTION public.reject_caller_campaign_snapshot_mutation();
