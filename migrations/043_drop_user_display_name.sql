UPDATE public.users
SET
  first_name = CASE
    WHEN first_name IS NULL OR btrim(first_name) = '' THEN split_part(primary_email_normalized, '@', 1)
    ELSE first_name
  END,
  last_name = CASE
    WHEN last_name IS NULL OR btrim(last_name) = '' THEN '-'
    ELSE last_name
  END
WHERE first_name IS NULL
  OR btrim(first_name) = ''
  OR last_name IS NULL
  OR btrim(last_name) = '';

ALTER TABLE public.users
  ALTER COLUMN first_name SET NOT NULL,
  ALTER COLUMN last_name SET NOT NULL,
  DROP CONSTRAINT IF EXISTS users_display_name_not_blank_check,
  DROP COLUMN IF EXISTS display_name;
