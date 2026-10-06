DROP INDEX IF EXISTS public.pa_password_resets_user_status_expires_at_idx;
DROP TABLE IF EXISTS public.platform_admin_password_resets;

DROP INDEX IF EXISTS public.pa_otp_challenges_purpose_created_at_idx;
DROP INDEX IF EXISTS public.pa_otp_challenges_user_purpose_status_expires_at_idx;
DROP TABLE IF EXISTS public.platform_admin_otp_challenges;
