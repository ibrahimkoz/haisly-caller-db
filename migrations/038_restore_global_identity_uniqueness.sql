ALTER TABLE public.user_credentials
  DROP CONSTRAINT user_credentials_user_type_unique;

ALTER TABLE public.user_credentials
  ADD CONSTRAINT user_credentials_type_identifier_unique UNIQUE (
    credential_type,
    identifier_normalized
  );

ALTER TABLE public.users
  DROP CONSTRAINT users_tenant_primary_email_normalized_unique;

ALTER TABLE public.users
  ADD CONSTRAINT users_primary_email_normalized_unique UNIQUE (primary_email_normalized);
