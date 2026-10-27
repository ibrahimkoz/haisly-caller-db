SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.billing_tariff_versions LIMIT 1) THEN
  RAISE EXCEPTION 'Published tariffs exist; retain historical rates and use a forward fix.';
 END IF;
END $$;
DROP TABLE public.billing_tariff_versions;
DROP FUNCTION public.guard_billing_tariff_version();
