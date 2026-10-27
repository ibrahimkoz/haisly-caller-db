-- Explicit draft knowledge selection. Immutable campaign snapshots capture the public pin manifest separately.
SET LOCAL lock_timeout = '5s';
ALTER TABLE public.knowledge_source_versions
 ADD CONSTRAINT knowledge_versions_id_source_tenant_unique UNIQUE (id, knowledge_source_id, tenant_id);
CREATE TABLE public.caller_campaign_knowledge_pins (
 tenant_id bigint NOT NULL,
 campaign_version_id bigint NOT NULL,
 knowledge_source_id bigint NOT NULL,
 knowledge_source_version_id bigint NOT NULL,
 priority integer NOT NULL CHECK (priority >= 0),
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY (campaign_version_id, knowledge_source_id),
 FOREIGN KEY (campaign_version_id, tenant_id) REFERENCES public.caller_campaign_versions(id, tenant_id) ON DELETE CASCADE,
 FOREIGN KEY (knowledge_source_version_id, knowledge_source_id, tenant_id)
  REFERENCES public.knowledge_source_versions(id, knowledge_source_id, tenant_id) ON DELETE RESTRICT
);
CREATE INDEX caller_campaign_knowledge_version_idx ON public.caller_campaign_knowledge_pins(tenant_id, knowledge_source_version_id);
CREATE FUNCTION public.guard_campaign_knowledge_pin() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE pinned_version public.knowledge_source_versions%ROWTYPE;
BEGIN
 -- Share the canonical tenant mutation lock before acquiring resource locks.
 PERFORM pg_advisory_xact_lock(hashtextextended('caller-contact:' || NEW.tenant_id::text, 0));
 IF TG_OP = 'UPDATE' AND (NEW.tenant_id, NEW.campaign_version_id, NEW.knowledge_source_id)
   IS DISTINCT FROM (OLD.tenant_id, OLD.campaign_version_id, OLD.knowledge_source_id) THEN
  RAISE EXCEPTION 'Knowledge pin ownership cannot change' USING ERRCODE = '23514';
 END IF;
 SELECT * INTO pinned_version FROM public.knowledge_source_versions
  WHERE id = NEW.knowledge_source_version_id AND tenant_id = NEW.tenant_id AND knowledge_source_id = NEW.knowledge_source_id
  FOR SHARE;
 IF NOT FOUND OR pinned_version.sealed_at IS NULL OR pinned_version.status <> 'published' THEN
  RAISE EXCEPTION 'Knowledge pin requires a sealed published version' USING ERRCODE = '23514';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER caller_campaign_knowledge_pin_guard BEFORE INSERT OR UPDATE ON public.caller_campaign_knowledge_pins
 FOR EACH ROW EXECUTE FUNCTION public.guard_campaign_knowledge_pin();
