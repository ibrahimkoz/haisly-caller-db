ALTER TABLE public.users
  ADD COLUMN display_name text;

UPDATE public.users
SET display_name = btrim(first_name || ' ' || last_name);

ALTER TABLE public.users
  ALTER COLUMN display_name SET NOT NULL,
  ALTER COLUMN first_name DROP NOT NULL,
  ALTER COLUMN last_name DROP NOT NULL,
  ADD CONSTRAINT users_display_name_not_blank_check CHECK (btrim(display_name) <> '');
