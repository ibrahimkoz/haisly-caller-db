ALTER TABLE public.users
  ADD COLUMN first_name text,
  ADD COLUMN last_name text;

UPDATE public.users
SET
  first_name = CASE
    WHEN btrim(display_name) = '' THEN NULL
    ELSE split_part(btrim(display_name), ' ', 1)
  END,
  last_name = CASE
    WHEN btrim(display_name) = '' THEN NULL
    WHEN strpos(btrim(display_name), ' ') = 0 THEN NULL
    ELSE nullif(
      btrim(
        substring(
          btrim(display_name)
          FROM length(split_part(btrim(display_name), ' ', 1)) + 1
        )
      ),
      ''
    )
  END
WHERE first_name IS NULL
  AND last_name IS NULL;

ALTER TABLE public.users
  ADD CONSTRAINT users_first_name_not_blank_check CHECK (
    first_name IS NULL OR btrim(first_name) <> ''
  ),
  ADD CONSTRAINT users_last_name_not_blank_check CHECK (
    last_name IS NULL OR btrim(last_name) <> ''
  );
