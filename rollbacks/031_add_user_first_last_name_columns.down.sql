ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_last_name_not_blank_check,
  DROP CONSTRAINT IF EXISTS users_first_name_not_blank_check,
  DROP COLUMN IF EXISTS last_name,
  DROP COLUMN IF EXISTS first_name;
