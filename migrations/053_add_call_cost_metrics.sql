ALTER TABLE public.calls
  ADD COLUMN total_tokens integer,
  ADD COLUMN total_cost numeric(18, 8),
  ADD COLUMN total_cost_per_minute numeric(18, 8);

ALTER TABLE public.calls
  ADD CONSTRAINT calls_total_tokens_non_negative_check CHECK (
    total_tokens IS NULL OR total_tokens >= 0
  ),
  ADD CONSTRAINT calls_total_cost_non_negative_check CHECK (
    total_cost IS NULL OR total_cost >= 0
  ),
  ADD CONSTRAINT calls_total_cost_per_minute_non_negative_check CHECK (
    total_cost_per_minute IS NULL OR total_cost_per_minute >= 0
  );
