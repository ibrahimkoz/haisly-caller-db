-- Run after migration130 during final database verification. No persistent writes.
BEGIN;
DO $$ BEGIN
  IF NOT public.caller_valid_https_origins('{}'::text[])
    OR NOT public.caller_valid_https_origins(ARRAY['https://docs.vendor.com']) THEN
    RAISE EXCEPTION 'Valid HTTPS policy rejected';
  END IF;
  IF public.caller_valid_https_origins(ARRAY['https://docs.vendor.com', 'https://docs.vendor.com'])
    OR public.caller_valid_https_origins(ARRAY['https://docs.vendor.com/path'])
    OR public.caller_valid_https_origins(ARRAY['http://docs.vendor.com'])
    OR public.caller_valid_https_origins(ARRAY['https://*.vendor.com'])
    OR public.caller_valid_https_origins(ARRAY[NULL]::text[])
    OR public.caller_valid_https_origins(ARRAY[['https://docs.vendor.com']])
    OR public.caller_valid_https_origins(array_fill('https://docs.vendor.com'::text, ARRAY[101])) THEN
    RAISE EXCEPTION 'Invalid HTTPS policy accepted';
  END IF;
END $$;
ROLLBACK;
