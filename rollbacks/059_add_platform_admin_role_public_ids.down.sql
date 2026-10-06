ALTER TABLE public.platform_admin_roles
  DROP CONSTRAINT IF EXISTS platform_admin_roles_public_id_unique;

ALTER TABLE public.platform_admin_roles
  DROP COLUMN IF EXISTS public_id;

