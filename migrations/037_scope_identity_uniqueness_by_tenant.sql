ALTER TABLE public.user_credentials
  DROP CONSTRAINT user_credentials_type_identifier_unique;

ALTER TABLE public.user_credentials
  ADD CONSTRAINT user_credentials_user_type_unique UNIQUE (user_id, credential_type);

ALTER TABLE public.users
  DROP CONSTRAINT users_primary_email_normalized_unique;

ALTER TABLE public.users
  ADD CONSTRAINT users_tenant_primary_email_normalized_unique UNIQUE (tenant_id, primary_email_normalized);
