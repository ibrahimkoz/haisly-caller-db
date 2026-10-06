ALTER TABLE public.platform_admin_roles
  ADD COLUMN public_id uuid NOT NULL DEFAULT gen_random_uuid();

ALTER TABLE public.platform_admin_roles
  ADD CONSTRAINT platform_admin_roles_public_id_unique UNIQUE (public_id);

