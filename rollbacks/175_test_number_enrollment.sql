SET LOCAL lock_timeout='5s';
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.caller_test_numbers) THEN RAISE EXCEPTION 'Cannot drop test number enrollment history'; END IF;
END $$;
DROP TABLE public.caller_test_numbers;
DROP FUNCTION public.guard_test_number_enrollment();
