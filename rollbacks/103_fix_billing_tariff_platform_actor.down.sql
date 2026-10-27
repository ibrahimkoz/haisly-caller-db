SET LOCAL lock_timeout = '5s';
LOCK TABLE public.billing_tariff_versions IN ACCESS EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.billing_tariff_versions LIMIT 1) THEN
  RAISE EXCEPTION 'Platform tariff history exists; use a forward fix.';
 END IF;
END $$;
ALTER TABLE public.billing_tariff_versions DROP CONSTRAINT billing_tariff_platform_actor_fkey;
ALTER TABLE public.billing_tariff_versions RENAME COLUMN published_by_platform_admin_user_id TO published_by_user_id;
ALTER TABLE public.billing_tariff_versions ADD CONSTRAINT billing_tariff_versions_published_by_user_id_fkey
 FOREIGN KEY(published_by_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;
