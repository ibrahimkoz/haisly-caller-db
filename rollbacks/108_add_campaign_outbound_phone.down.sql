SET LOCAL lock_timeout = '5s';
LOCK TABLE public.caller_campaign_versions IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_campaign_versions WHERE outbound_phone_number_id IS NOT NULL) THEN
  RAISE EXCEPTION 'Campaign phone selections exist; use a forward fix.';
 END IF;
END $$;
DROP INDEX public.caller_campaign_outbound_phone_idx;
ALTER TABLE public.caller_campaign_versions DROP CONSTRAINT caller_campaign_outbound_phone_fk, DROP COLUMN outbound_phone_number_id;
