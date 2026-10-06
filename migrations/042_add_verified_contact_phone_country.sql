ALTER TABLE public.user_verified_contacts
  ADD COLUMN phone_country_iso2 text,
  ADD COLUMN phone_calling_code text;

ALTER TABLE public.user_verified_contacts
  ADD CONSTRAINT user_verified_contacts_phone_country_iso2_check CHECK (
    phone_country_iso2 IS NULL OR phone_country_iso2 ~ '^[A-Z]{2}$'
  ),
  ADD CONSTRAINT user_verified_contacts_phone_calling_code_check CHECK (
    phone_calling_code IS NULL OR phone_calling_code ~ '^\+[1-9][0-9]{0,4}$'
  ),
  ADD CONSTRAINT user_verified_contacts_email_phone_country_empty_check CHECK (
    contact_type = 'phone' OR (
      phone_country_iso2 IS NULL AND phone_calling_code IS NULL
    )
  );
