SET LOCAL lock_timeout = '5s';
LOCK TABLE public.caller_campaign_knowledge_pins IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM public.caller_campaign_knowledge_pins) THEN
  RAISE EXCEPTION 'Cannot rollback campaign knowledge pins while selections exist';
 END IF;
END $$;
DROP TABLE public.caller_campaign_knowledge_pins;
DROP FUNCTION public.guard_campaign_knowledge_pin();
ALTER TABLE public.knowledge_source_versions DROP CONSTRAINT knowledge_versions_id_source_tenant_unique;
