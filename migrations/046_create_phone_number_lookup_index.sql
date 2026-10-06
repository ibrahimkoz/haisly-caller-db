CREATE INDEX phone_numbers_phone_number_lookup_idx
  ON public.phone_numbers (phone_number, status);
