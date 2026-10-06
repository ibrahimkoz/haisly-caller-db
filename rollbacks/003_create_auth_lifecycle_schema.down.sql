DROP TABLE IF EXISTS public.mfa_recovery_requests;
DROP TABLE IF EXISTS public.mfa_factors;
DROP TABLE IF EXISTS public.otp_challenges;
DROP TABLE IF EXISTS public.password_resets;
DROP TABLE IF EXISTS public.refresh_tokens;
DROP TABLE IF EXISTS public.sessions;

ALTER TABLE public.user_verified_contacts
  DROP CONSTRAINT IF EXISTS user_verified_contacts_id_user_id_unique;

ALTER TABLE public.user_credentials
  DROP CONSTRAINT IF EXISTS user_credentials_id_user_id_unique;

ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_id_tenant_id_unique;
