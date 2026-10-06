ALTER TABLE public.customers
  ADD COLUMN first_name text,
  ADD COLUMN last_name text;

UPDATE public.customers
SET
  first_name = CASE
    WHEN btrim(display_name) = '' THEN 'Musteri'
    ELSE split_part(btrim(display_name), ' ', 1)
  END,
  last_name = CASE
    WHEN btrim(display_name) = '' THEN '-'
    WHEN strpos(btrim(display_name), ' ') = 0 THEN '-'
    ELSE COALESCE(
      nullif(
        btrim(
          substring(
            btrim(display_name)
            FROM length(split_part(btrim(display_name), ' ', 1)) + 1
          )
        ),
        ''
      ),
      '-'
    )
  END
WHERE first_name IS NULL
  AND last_name IS NULL;

ALTER TABLE public.customers
  ALTER COLUMN first_name SET NOT NULL,
  ALTER COLUMN last_name SET NOT NULL,
  ADD CONSTRAINT customers_first_name_not_blank_check CHECK (btrim(first_name) <> ''),
  ADD CONSTRAINT customers_last_name_not_blank_check CHECK (btrim(last_name) <> '');

CREATE INDEX customers_tenant_name_idx
  ON public.customers (tenant_id, last_name, first_name);
