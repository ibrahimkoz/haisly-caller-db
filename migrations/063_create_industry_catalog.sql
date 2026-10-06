CREATE TABLE public.industries (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id uuid NOT NULL DEFAULT gen_random_uuid(),
  code text NOT NULL,
  name text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT industries_public_id_unique UNIQUE (public_id),
  CONSTRAINT industries_code_unique UNIQUE (code),
  CONSTRAINT industries_code_format_check CHECK (
    code ~ '^[a-z][a-z0-9_]{1,79}$'
  ),
  CONSTRAINT industries_name_not_blank_check CHECK (btrim(name) <> ''),
  CONSTRAINT industries_status_check CHECK (status IN (
    'active',
    'inactive',
    'deprecated'
  )),
  CONSTRAINT industries_sort_order_non_negative_check CHECK (sort_order >= 0)
);

CREATE INDEX industries_status_sort_order_code_idx
  ON public.industries (status, sort_order, code);

INSERT INTO public.industries (
  code,
  name,
  status,
  sort_order
)
VALUES
  (
    'hospitality_accommodation',
    'Otelcilik & Konaklama',
    'active',
    10
  ),
  (
    'food_beverage_restaurant',
    'Yeme-İçme & Restaurant',
    'active',
    20
  );

COMMENT ON TABLE public.industries IS
  'Global industry catalog used to select sector-specific product configuration.';
