SET LOCAL lock_timeout = '5s';
LOCK TABLE public.caller_campaign_versions IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_campaign_versions
   WHERE brand_name_override IS NOT NULL OR assistant_name_override IS NOT NULL)
 OR EXISTS(SELECT 1 FROM public.caller_campaign_snapshots
   WHERE document->'settings'->>'brand_name_override' IS NOT NULL
      OR document->'settings'->>'assistant_name_override' IS NOT NULL) THEN
  RAISE EXCEPTION 'Campaign identity overrides exist; use a forward fix.';
 END IF;
END $$;
ALTER TABLE public.caller_campaign_versions
 DROP CONSTRAINT caller_campaign_brand_override_check,
 DROP CONSTRAINT caller_campaign_assistant_override_check,
 DROP COLUMN brand_name_override,
 DROP COLUMN assistant_name_override;
