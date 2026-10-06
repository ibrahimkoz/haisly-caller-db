ALTER TABLE public.calls
  DROP CONSTRAINT IF EXISTS calls_total_cost_per_minute_non_negative_check,
  DROP CONSTRAINT IF EXISTS calls_total_cost_non_negative_check,
  DROP CONSTRAINT IF EXISTS calls_total_tokens_non_negative_check;

ALTER TABLE public.calls
  DROP COLUMN IF EXISTS total_cost_per_minute,
  DROP COLUMN IF EXISTS total_cost,
  DROP COLUMN IF EXISTS total_tokens;
