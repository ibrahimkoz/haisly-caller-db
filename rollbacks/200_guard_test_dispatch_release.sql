SET LOCAL lock_timeout='5s';
-- Disable test dispatch and billing mutations before removing this guard.
DROP TRIGGER caller_test_dispatch_release_guard ON public.billing_reservations;
DROP FUNCTION public.guard_submitted_test_dispatch_release();
