ALTER TABLE public.user_verified_contacts
  DROP CONSTRAINT IF EXISTS user_verified_contacts_email_phone_country_empty_check,
  DROP CONSTRAINT IF EXISTS user_verified_contacts_phone_calling_code_check,
  DROP CONSTRAINT IF EXISTS user_verified_contacts_phone_country_iso2_check;

ALTER TABLE public.user_verified_contacts
  DROP COLUMN IF EXISTS phone_calling_code,
  DROP COLUMN IF EXISTS phone_country_iso2;
